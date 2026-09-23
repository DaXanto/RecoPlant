// home_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:pytorch_lite/pytorch_lite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:recoplant/widgets/animated_gradient_button.dart';
import 'package:recoplant/templates/top_bar.dart';
import 'package:recoplant/widgets/save_likes.dart';

import 'package:recoplant/utils/firebase_service.dart';

const String CLOUD_API_URL = "http://35.234.247.175:8000/predict";
const Duration CLOUD_TIMEOUT = Duration(seconds: 12);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  File? _image;
  String? _predictedLabelName;
  double? _predictedConfidence;
  ClassificationModel? _model;
  bool _isModelLoaded = false;
  bool _isModelLoading = false;
  List<String> _classNames = [];
  bool _isProcessing = false;

  // Connectivity
  bool _isOnline = false;
  late final Connectivity _connectivity;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // New: persistently show which model is used
  String _modelSource = "Waiting...";

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity();
    _listenConnectivity();
    _initializeAsync();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _listenConnectivity() async {
    final initial = await _connectivity.checkConnectivity();
    _updateOnlineStatus(initial);

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _updateOnlineStatus(result);
    });
  }

  void _updateOnlineStatus(ConnectivityResult result) {
    final bool nowOnline = (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi);
    if (!mounted) return;
    setState(() {
      _isOnline = nowOnline;
      _modelSource = _isOnline ? "Cloud available (will use cloud when identifying)" : "Offline (will use local model)";
    });
    print("🌐 Connectivity changed: $_isOnline");
  }

  Future<void> _initializeAsync() async {
    await _loadLabels();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _loadModel();
    });
  }

  Future<void> _loadLabels() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/models/labels.json');
      final Map<String, dynamic> labelsMap = jsonDecode(jsonString);
      if (!mounted) return;
      setState(() {
        _classNames = labelsMap.values.toList().cast<String>();
      });
    } catch (e) {
      print("❌ Error loading labels: $e");
    }
  }

  Future<void> _loadModel() async {
    if (_isModelLoading || _isModelLoaded) return;

    if (mounted) setState(() => _isModelLoading = true);

    try {
      _model = await PytorchLite.loadClassificationModel(
        'assets/models/model_mobile.pt',
        224,
        224,
        _classNames.length,
      );
      if (!mounted) return;
      setState(() {
        _isModelLoaded = true;
        _isModelLoading = false;
      });
      print("✅ Model loaded");
    } catch (e, st) {
      print("❌ Error loading model: $e\n$st");
      if (!mounted) return;
      setState(() => _isModelLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load AI model. Please restart the app.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePicture() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked != null && mounted) {
        setState(() {
          _image = File(picked.path);
          _predictedLabelName = null;
          _predictedConfidence = null;
        });
      }
    } catch (e) {
      print("❌ Error taking picture: $e");
    }
  }

  Future<void> _importPicture() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked != null && mounted) {
        setState(() {
          _image = File(picked.path);
          _predictedLabelName = null;
          _predictedConfidence = null;
        });
      }
    } catch (e) {
      print("❌ Error importing picture: $e");
    }
  }

  /// NEUF : upload + saveAnalysis using the provided FirebaseService API
  Future<void> _saveAnalysis(File image, String label, double confidence, {String description = "", bool isDisease = false, String? plantId}) async {
    try {
      // Utilise la nouvelle méthode uploadImageAndOptionallyCreatePlant
      final result = await firebaseService.uploadImageAndOptionallyCreatePlant(
        imageFile: image,
        createPlantEntry: false,
      );

      final String? downloadUrl = result['downloadUrl'] as String?;
      // si pas d'URL, on lève une erreur pour debug
      if (downloadUrl == null) {
        throw Exception('Upload did not return a downloadUrl');
      }

      // Sauvegarde l'analyse avec l'URL renvoyée
      await firebaseService.saveAnalysis(
        imageUrl: downloadUrl,
        label: label,
        confidence: confidence,
        description: description.isNotEmpty ? description : 'Prédiction depuis app',
        isDisease: isDisease,
        plantId: plantId,
      );

      print("✅ Analyse sauvegardée dans Firebase: $downloadUrl");
    } catch (e, st) {
      print("❌ Erreur sauvegarde Firebase: $e\n$st");
      // Optionnel : afficher un SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur sauvegarde Firebase : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Wrapper that chooses cloud vs local
  Future<void> _identifyPlant() async {
    if (_image == null || _isProcessing) return;

    if (mounted) setState(() => _isProcessing = true);

    try {
      if (_isOnline) {
        print("➡️ Device online — using cloud model");
        if (mounted) setState(() => _modelSource = "Cloud model active");
        await _identifyPlantCloud();
      } else {
        print("➡️ Device offline — using local model");
        if (mounted) setState(() => _modelSource = "Local model active");
        await _identifyPlantLocal();
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // Local identification
  Future<void> _identifyPlantLocal() async {
    if (_image == null) return;
    if (_model == null || !_isModelLoaded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local model not ready.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final Uint8List bytes = await _image!.readAsBytes();
      final img.Image? original = img.decodeImage(bytes);

      if (original == null) {
        print("⚠️ Cannot decode image bytes");
        return;
      }

      final img.Image resized = img.copyResize(
        original,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );

      final Uint8List byteInput = Uint8List.fromList(img.encodeJpg(resized, quality: 90));
      final List<dynamic> result = await _model!.getImagePredictionList(byteInput);

      if (result.length != 2) {
        print("⚠️ Unexpected local model result format: $result");
        return;
      }

      final double confidence = result[0];
      final int classIndex = result[1].toInt();
      final String className = (classIndex >= 0 && classIndex < _classNames.length)
          ? _classNames[classIndex]
          : "Unknown";

      if (!mounted) return;
      setState(() {
        _predictedConfidence = confidence * 100;
        _predictedLabelName = className;
      });

      print("✅ Predicted (local): $className (${(confidence * 100).toStringAsFixed(2)}%)");

      // Utilise la nouvelle _saveAnalysis (upload + save)
      await _saveAnalysis(_image!, className, confidence * 100, description: "Local prediction", isDisease: false);

    } catch (e, st) {
      print("⚠️ Error processing image (local): $e\n$st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error processing image locally.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Cloud identification: send image as multipart 'file'
  Future<void> _identifyPlantCloud() async {
    if (_image == null) return;

    try {
      final request = http.MultipartRequest('POST', Uri.parse(CLOUD_API_URL));
      final bytes = await _image!.readAsBytes();

      request.files.add(
        http.MultipartFile.fromBytes(
          'file', // field expected by your API
          bytes,
          filename: 'upload.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send().timeout(CLOUD_TIMEOUT);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        print("❌ Cloud response code: ${response.statusCode}, body: ${response.body}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cloud identification failed (${response.statusCode}).'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final body = jsonDecode(response.body);
      final label = (body['label'] ?? 'Unknown').toString();
      double rawConfidence = (body['confidence'] is num) ? (body['confidence'] as num).toDouble() : 0.0;
      final confidencePercent = (rawConfidence > 1.0) ? rawConfidence : rawConfidence * 100.0;

      if (!mounted) return;
      setState(() {
        _predictedLabelName = label;
        _predictedConfidence = confidencePercent;
      });

      print("✅ Predicted (cloud): $label (${confidencePercent.toStringAsFixed(2)}%)");

      // Utilise la nouvelle _saveAnalysis (upload + save)
      await _saveAnalysis(_image!, label, confidencePercent, description: "Cloud prediction", isDisease: false);

    } on TimeoutException catch (_) {
      print("⚠️ Cloud request timed out");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloud request timed out. Try again or switch to local mode.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e, st) {
      print("⚠️ Error calling cloud API: $e\n$st");
      if (_model != null && _isModelLoaded) {
        print("↩️ Falling back to local model due to cloud error");
        await _identifyPlantLocal();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error contacting cloud model.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final double frameHeight = _image != null ? 300 : 0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const TopBar(),
            if (_image == null) ...[
              Image.asset(
                'assets/images/plante_tombante.webp',
                height: 300,
                fit: BoxFit.contain,
                cacheWidth: 600,
              ),
              const SizedBox(height: 10),
              Text(
                'IDENTIFY\nA\nPLANT',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  color: const Color(0xFF639636),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  height: 0.9,
                ),
              ),
              const SizedBox(height: 20),

              // Indication online/offline
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isOnline ? Icons.cloud : Icons.wifi_off,
                      size: 16, color: _isOnline ? Colors.blue : Colors.grey),
                  const SizedBox(width: 6),
                  Text(_isOnline ? 'Online (cloud available)' : 'Offline (using local model)',
                      style: const TextStyle(fontSize: 12))
                ],
              ),

              const SizedBox(height: 10),

              if (_isModelLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Loading AI model...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),

              AnimatedGradientButton(
                icon: Icons.add_a_photo_outlined,
                label: "Take a picture",
                onPressed: _takePicture,
              ),
              const SizedBox(height: 15),
              AnimatedGradientButton(
                icon: Icons.add_photo_alternate_outlined,
                label: "Import a picture",
                onPressed: _importPicture,
              ),
              const SizedBox(height: 40),
            ] else ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: frameHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                  image: DecorationImage(
                    image: FileImage(_image!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Text(
                _modelSource,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              if (_predictedLabelName == null) ...[
                _isProcessing
                    ? const CircularProgressIndicator()
                    : AnimatedGradientButton(
                  icon: Icons.search,
                  label: "Identify",
                  onPressed: _identifyPlant,
                ),
              ],

              if (_predictedLabelName != null) ...[
                const SizedBox(height: 20),
                Text(
                  '$_predictedLabelName\n(${_predictedConfidence!.toStringAsFixed(2)}%)',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                AnimatedGradientButton(
                  icon: Icons.favorite,
                  label: "Save to Likes",
                  onPressed: () {
                    if (_image != null &&
                        _predictedLabelName != null &&
                        _predictedConfidence != null) {
                      saveLike(context, _image!, _predictedLabelName!, _predictedConfidence!, type: "plant");

                    }
                  },
                ),
              ],
              const SizedBox(height: 100),
            ],
          ],
        ),
      ),
    );
  }
}

















