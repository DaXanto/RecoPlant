// disease_detection_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:recoplant/widgets/animated_gradient_button.dart';
import 'package:recoplant/templates/top_bar.dart';
import 'package:recoplant/widgets/save_likes.dart';

import 'package:recoplant/utils/firebase_service.dart';

const String CLOUD_API_URL = "http://35.202.115.225:8000/predict";
const Duration CLOUD_TIMEOUT = Duration(seconds: 12);

class DiseaseDetectionPage extends StatefulWidget {
  const DiseaseDetectionPage({super.key});

  @override
  State<DiseaseDetectionPage> createState() => _DiseaseDetectionPageState();
}

class _DiseaseDetectionPageState extends State<DiseaseDetectionPage> {
  File? _image;
  String? _predictedDiseaseName;
  double? _predictedConfidence;
  bool _isProcessing = false;

  // Connectivity
  bool _isOnline = false;
  late final Connectivity _connectivity;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Permanent model source label
  String _modelSource = "Waiting...";

  // TFLite interpreter and labels
  Interpreter? _interpreter;
  List<String> _labels = [];
  final String _tfliteModel = 'assets/models/plant_disease_fp32.tflite';
  final String _labelsFile = 'assets/models/labels.txt';
  final int _inputSize = 128; // à adapter selon ton modèle

  // Model loading state
  bool _isModelLoading = false;
  bool _isModelLoaded = false;

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
    _interpreter?.close();
    super.dispose();
  }

  void _listenConnectivity() async {
    final initial = await _connectivity.checkConnectivity();
    _updateOnlineStatus(initial);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateOnlineStatus);
  }

  void _updateOnlineStatus(ConnectivityResult result) {
    final bool nowOnline = (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi);
    if (!mounted) return;
    setState(() {
      _isOnline = nowOnline;
      _modelSource = _isOnline ? "Cloud available (will use cloud when identifying)" : "Offline (local fallback)";
    });
  }

  Future<void> _initializeAsync() async {
    await _loadLabels();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _loadModel();
    });
  }

  Future<void> _loadLabels() async {
    try {
      final String labelsData = await rootBundle.loadString(_labelsFile);
      _labels = labelsData
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      print("✅ Loaded ${_labels.length} labels");
    } catch (e) {
      print("❌ Failed to load labels: $e");
    }
  }

  Future<void> _loadModel() async {
    if (_isModelLoading || _isModelLoaded) return;

    setState(() => _isModelLoading = true);

    try {
      _interpreter = await Interpreter.fromAsset(_tfliteModel);
      setState(() {
        _isModelLoaded = true;
        _isModelLoading = false;
      });
      print("✅ Local TFLite model loaded");
    } catch (e) {
      setState(() => _isModelLoading = false);
      print("❌ Failed to load TFLite model: $e");
    }
  }

  Future<void> _takePicture() async {
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
        _predictedDiseaseName = null;
        _predictedConfidence = null;
      });
    }
  }

  Future<void> _importPicture() async {
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
        _predictedDiseaseName = null;
        _predictedConfidence = null;
      });
    }
  }

  /// Mise à jour : upload + saveAnalysis via uploadImageAndOptionallyCreatePlant(...)
  Future<void> _saveAnalysis(File image, String label, double confidence, {String description = "", String? plantId}) async {
    try {
      final result = await firebaseService.uploadImageAndOptionallyCreatePlant(
        imageFile: image,
        createPlantEntry: false,
      );

      final String? downloadUrl = result['downloadUrl'] as String?;
      if (downloadUrl == null) {
        throw Exception('Upload did not return a downloadUrl');
      }

      await firebaseService.saveAnalysis(
        imageUrl: downloadUrl,
        label: label,
        confidence: confidence,
        description: description.isNotEmpty ? description : 'Prédiction depuis app',
        isDisease: true,
        plantId: plantId,
      );

      print("✅ Disease analysis saved in Firebase: $downloadUrl");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analyse sauvegardée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, st) {
      print("❌ Error saving disease analysis: $e\n$st");
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

  Future<void> _identifyDisease() async {
    if (_image == null || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      if (_isOnline) {
        setState(() => _modelSource = "Cloud model active");
        await _identifyDiseaseCloud();
      } else {
        setState(() => _modelSource = "Local model active");
        await _identifyDiseaseLocal();
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _identifyDiseaseLocal() async {
    if (_image == null || _interpreter == null) return;

    try {
      Uint8List bytes = await _image!.readAsBytes();
      final img.Image? imageInput = img.decodeImage(bytes);
      if (imageInput == null) return;

      final img.Image resized = img.copyResize(imageInput, width: _inputSize, height: _inputSize);

      var input = List.generate(_inputSize, (y) => List.generate(_inputSize, (x) => List.filled(3, 0.0)));
      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final pixel = resized.getPixel(x, y);
          input[y][x][0] = pixel.r / 255.0;
          input[y][x][1] = pixel.g / 255.0;
          input[y][x][2] = pixel.b / 255.0;
        }
      }

      var inputBatch = [input];
      var output = [List.filled(_labels.length, 0.0)];

      _interpreter!.run(inputBatch, output);

      double topProb = output[0][0];
      int topIndex = 0;
      for (int i = 1; i < output[0].length; i++) {
        if (output[0][i] > topProb) {
          topProb = output[0][i];
          topIndex = i;
        }
      }

      setState(() {
        _predictedDiseaseName = _labels[topIndex];
        _predictedConfidence = topProb * 100;
      });

      print("✅ Predicted (local): ${_labels[topIndex]} (${(topProb * 100).toStringAsFixed(2)}%)");
      await _saveAnalysis(_image!, _labels[topIndex], topProb * 100, description: "Local disease prediction");
    } catch (e, st) {
      print("❌ Error running local inference: $e\n$st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur inference locale'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _identifyDiseaseCloud() async {
    if (_image == null) return;

    try {
      Uint8List bytes = await _image!.readAsBytes();
      final img.Image? original = img.decodeImage(bytes);
      if (original != null) {
        final img.Image resized = img.copyResize(original, width: 512, height: (512 * original.height / original.width).round());
        bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
      }

      final uri = Uri.parse(CLOUD_API_URL);
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'upload.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));

      final streamed = await request.send().timeout(CLOUD_TIMEOUT);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) throw Exception("Cloud response: ${response.statusCode}");

      final Map<String, dynamic> body = jsonDecode(response.body);
      final String label = (body['label'] ?? 'Unknown').toString();
      double rawConfidence = 0.0;
      if (body['confidence'] is num) rawConfidence = (body['confidence'] as num).toDouble();
      else if (body['confidence'] is String) rawConfidence = double.tryParse(body['confidence']) ?? 0.0;

      final double confidencePercent = (rawConfidence > 1.0) ? rawConfidence : (rawConfidence * 100.0);

      setState(() {
        _predictedDiseaseName = label;
        _predictedConfidence = confidencePercent;
      });

      print("✅ Predicted (cloud): $label (${confidencePercent.toStringAsFixed(2)}%)");
      await _saveAnalysis(_image!, label, confidencePercent, description: "Cloud disease prediction");
    } on TimeoutException catch (_) {
      print("⚠️ Cloud timeout, fallback to local");
      setState(() => _modelSource = "Local model active (fallback)");
      await _identifyDiseaseLocal();
    } catch (e, st) {
      print("⚠️ Cloud error: $e, fallback to local\n$st");
      setState(() => _modelSource = "Local model active (fallback)");
      await _identifyDiseaseLocal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double frameHeight = _image != null ? 300 : 0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            const TopBar(),
            if (_image == null) ...[
              Image.asset(
                'assets/images/plante_tombante.webp',
                height: 300,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 10),
              Text(
                'DETECT\nDISEASE',
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isOnline ? Icons.cloud : Icons.wifi_off,
                      size: 16, color: _isOnline ? Colors.blue : Colors.grey),
                  const SizedBox(width: 6),
                  Text(_isOnline ? 'Online (cloud available)' : 'Offline (local model)',
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
                ),
              ),
              const SizedBox(height: 12),
              if (_predictedDiseaseName == null) ...[
                _isProcessing
                    ? const CircularProgressIndicator()
                    : AnimatedGradientButton(
                  icon: Icons.search,
                  label: "Identify Disease",
                  onPressed: _identifyDisease,
                ),
              ],
              if (_predictedDiseaseName != null) ...[
                const SizedBox(height: 20),
                Text(
                  '$_predictedDiseaseName\n(${_predictedConfidence!.toStringAsFixed(2)}%)',
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
                        _predictedDiseaseName != null &&
                        _predictedConfidence != null) {
                      saveLike(context, _image!, _predictedDiseaseName!, _predictedConfidence!, type: "disease");
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






