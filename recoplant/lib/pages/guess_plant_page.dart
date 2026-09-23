// guess_plant_page.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:recoplant/pages/Main_page.dart';
import 'package:recoplant/templates/top_bar.dart';
import 'package:recoplant/widgets/animated_gradient_button.dart';

class GuessPlantsPage extends StatefulWidget {
  const GuessPlantsPage({super.key});

  @override
  State<GuessPlantsPage> createState() => _GuessPlantsPageState();
}

class _GuessPlantsPageState extends State<GuessPlantsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<DocumentSnapshot> _analyses = [];
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _skipped = {};

  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadAnalyses();
  }

  @override
  void dispose() {
    for (var c in _controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyses() async {
    setState(() {
      _loading = true;
      _analyses = [];
      _controllers.clear();
      _skipped.clear();
    });

    try {
      const int fetchLimit = 200;
      final QuerySnapshot snapshot = await _firestore
          .collection('analyses')
          .where('is_disease', isEqualTo: false)
          .limit(fetchLimit)
          .get();

      final docsWithImage = snapshot.docs.where((d) {
        final data = d.data() as Map<String, dynamic>?;
        final imageUrl = data == null ? '' : (data['image_url'] ?? '').toString();
        return imageUrl.isNotEmpty;
      }).toList();

      docsWithImage.sort((a, b) {
        final aTs = (a.data() as Map<String, dynamic>?)?['timestamp'];
        final bTs = (b.data() as Map<String, dynamic>?)?['timestamp'];
        final aMillis = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
        final bMillis = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
        return bMillis.compareTo(aMillis);
      });

      if (docsWithImage.isEmpty) {
        setState(() {
          _loading = false;
          _analyses = [];
        });
        return;
      }

      final rng = Random();
      final int want = min(3, docsWithImage.length);
      final Set<int> chosen = {};
      while (chosen.length < want) {
        chosen.add(rng.nextInt(docsWithImage.length));
      }
      final selected = chosen.map((i) => docsWithImage[i]).toList();

      setState(() {
        _analyses = selected;
        for (var a in _analyses) {
          final ctrl = TextEditingController();
          ctrl.addListener(() {
            if (mounted) setState(() {});
          });
          _controllers[a.id] = ctrl;
          _skipped[a.id] = false;
        }
        _loading = false;
      });
    } catch (e, st) {
      print("Erreur _loadAnalyses: $e\n$st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur récupération des analyses : $e')),
        );
      }
      setState(() {
        _loading = false;
        _analyses = [];
      });
    }
  }

  bool get _hasAnyAnswer {
    for (var a in _analyses) {
      final id = a.id;
      final hasText = (_controllers[id]?.text.trim().isNotEmpty ?? false);
      final isSkipped = (_skipped[id] ?? false);
      if (hasText || isSkipped) return true;
    }
    return false;
  }

  Future<void> _submitAnswers() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final user = _auth.currentUser;
    final String? uid = user?.uid;
    final WriteBatch batch = _firestore.batch();

    try {
      final List<Map<String, dynamic>> toSubmit = [];

      for (var analysis in _analyses) {
        final String analysisId = analysis.id;
        final data = analysis.data() as Map<String, dynamic>;
        final String groundTruthLabel = (data['label'] ?? '').toString();
        final String imageUrl = (data['image_url'] ?? '').toString();
        final String answer = _controllers[analysisId]!.text.trim();
        final bool skipped = _skipped[analysisId] ?? false;

        // skip skippeds or empty answers
        if (skipped) continue;
        if (answer.isEmpty) continue;

        // NEW: give 10 points for any answered item (regardless correctness)
        final int pointsEarned = 10;

        final bool isCorrect = answer.toLowerCase() == groundTruthLabel.toLowerCase();

        toSubmit.add({
          'analysisId': analysisId,
          'label': groundTruthLabel,
          'image_url': imageUrl,
          'answer': answer,
          'isCorrect': isCorrect,
          'skipped': false,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': uid,
          'source': 'guess_from_analyses_v2',
          'pointsEarned': pointsEarned,
        });
      }

      if (toSubmit.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune réponse à envoyer (les items skippés ne sont pas envoyés).')),
          );
          await Future.delayed(const Duration(milliseconds: 600));
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainPage()));
        }
        return;
      }

      // add user_contributions documents to batch
      for (var item in toSubmit) {
        final docRef = _firestore.collection('user_contributions').doc();
        batch.set(docRef, item);
      }

      // compute total points to award = 10 * number of submitted answers
      final int totalPoints = toSubmit.length * 10;

      if (uid != null && totalPoints > 0) {
        final userRef = _firestore.collection('users').doc(uid);
        // update user's points atomically
        batch.update(userRef, {'points': FieldValue.increment(totalPoints)});
      }

      await batch.commit();

      if (mounted) {
        if (uid == null && totalPoints > 0) {
          // user not logged in but had answers -> inform to login for points
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Merci ! Connecte-toi pour recevoir des points.'),
              backgroundColor: Colors.orange,
            ),
          );
        } else if (totalPoints > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Merci pour vos contributions ! +$totalPoints points ajoutés.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Merci pour vos contributions !'), backgroundColor: Colors.green),
          );
        }

        await Future.delayed(const Duration(milliseconds: 600));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainPage()));
      }
    } catch (e, st) {
      print("Erreur _submitAnswers: $e\n$st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur enregistrement contributions : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildCardForAnalysis(DocumentSnapshot analysis) {
    final data = analysis.data() as Map<String, dynamic>;
    final imageUrl = (data['image_url'] ?? '').toString();
    final label = (data['label'] ?? '').toString();
    final timestamp = data['timestamp'];
    final String timeText = timestamp is Timestamp
        ? TimeOfDay.fromDateTime(timestamp.toDate()).format(context)
        : '';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.isNotEmpty
                  ? GestureDetector(
                onTap: () => _showFullImage(imageUrl),
                child: Image.network(imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover),
              )
                  : Container(
                height: 180,
                color: Colors.grey[200],
                alignment: Alignment.center,
                child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (label.isNotEmpty)
                  Chip(
                    label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    backgroundColor: Colors.green[50],
                    avatar: const Icon(Icons.local_florist, size: 18, color: Colors.green),
                  ),
                const Spacer(),
                if (timeText.isNotEmpty)
                  Text(timeText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controllers[analysis.id],
              decoration: InputDecoration(
                hintText: 'Tape le nom de la plante...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              enabled: !(_skipped[analysis.id] ?? false),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(_skipped[analysis.id]! ? Icons.undo : Icons.skip_next),
                    label: Text(_skipped[analysis.id]! ? 'Annuler skip' : 'Skip'),
                    onPressed: () {
                      setState(() {
                        _skipped[analysis.id] = !(_skipped[analysis.id] ?? false);
                        if (_skipped[analysis.id] == true) {
                          _controllers[analysis.id]?.text = '';
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.visibility),
                    label: const Text('Voir prédiction'),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (_) => Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Prédiction enregistrée', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(label.isNotEmpty ? label : 'Aucune prédiction', style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 12),
                              const Text('Merci d’aider notre IA — ta contribution améliore le modèle.'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: EdgeInsets.zero,
        child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_analyses.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Aide notre IA")),
        body: SafeArea(
          child: Column(
            children: [
              const TopBar(),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.analytics, size: 88, color: Colors.grey[400]),
                        const SizedBox(height: 18),
                        Text("Aucune image disponible pour le moment.", textAlign: TextAlign.center, style: GoogleFonts.playfairDisplay(fontSize: 20)),
                        const SizedBox(height: 14),
                        Text("Reviens plus tard ou retourne à l'accueil.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 26),
                        AnimatedGradientButton(
                          icon: Icons.home,
                          label: "Retour à l'accueil",
                          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainPage())),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE8F0D9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            children: [
              const TopBar(),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Identifie les plantes', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              Text('Aide notre modèle en identifiant correctement ces images.', style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 12),

              for (var a in _analyses) _buildCardForAnalysis(a),

              const SizedBox(height: 8),

              AnimatedGradientButton(
                icon: _submitting ? Icons.hourglass_top : Icons.check,
                label: _submitting ? "Envoi..." : "Valider mes réponses",
                onPressed: (!_hasAnyAnswer || _submitting) ? () {} : _submitAnswers,
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}








