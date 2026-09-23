import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:recoplant/templates/top_bar.dart';
import 'package:recoplant/widgets/save_likes.dart'; // pour loadLikes(), getLocalLikesFile()

class LikesPage extends StatefulWidget {
  const LikesPage({super.key});

  @override
  State<LikesPage> createState() => _LikesPageState();
}

class _LikesPageState extends State<LikesPage> {
  List<Map<String, dynamic>> _likes = [];
  List<Map<String, dynamic>> _filteredLikes = [];
  String _filterType = "All"; // All, Label, Disease

  @override
  void initState() {
    super.initState();
    _loadAllLikes();
  }

  Future<void> _loadAllLikes() async {
    final likes = await loadLikes();
    if (!mounted) return;
    setState(() {
      _likes = likes;
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_filterType == "All") {
      _filteredLikes = List.from(_likes);
    } else if (_filterType == "Label") {
      _filteredLikes =
          _likes.where((like) => like['type'] == 'plant').toList();
    } else if (_filterType == "Disease") {
      _filteredLikes =
          _likes.where((like) => like['type'] == 'disease').toList();
    }
  }

  Future<void> _deleteLike(int index) async {
    final likeToRemove = _filteredLikes[index];

    try {
      // Supprimer le fichier image si il existe
      final file = File(likeToRemove['image_path']);
      if (await file.exists()) await file.delete();

      // Retirer l'élément de la liste principale
      _likes.removeWhere((like) => like['image_path'] == likeToRemove['image_path']);

      // Mettre à jour le fichier JSON
      final likesFile = await getLocalLikesFile();
      await likesFile.writeAsString(jsonEncode(_likes), flush: true);

      // Rafraîchir l'affichage
      if (!mounted) return;
      setState(() {
        _applyFilter();
      });

      // Afficher le message orange
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Like deleted"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print("❌ Error deleting like: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to delete like"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            const TopBar(),
            const SizedBox(height: 20),
            Text(
              'LIKES',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 32,
                color: const Color(0xFF639636),
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),

            // Filtres
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFilterButton("All"),
                const SizedBox(width: 10),
                _buildFilterButton("Label"),
                const SizedBox(width: 10),
                _buildFilterButton("Disease"),
              ],
            ),
            const SizedBox(height: 20),

            // Contenu dynamique
            _filteredLikes.isEmpty
                ? const Center(child: Text("No saved likes yet."))
                : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _filteredLikes.length,
              itemBuilder: (context, index) {
                final like = _filteredLikes[index];
                return Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: Image.file(
                            File(like['image_path']),
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${like['label']} (${like['confidence'].toStringAsFixed(2)}%)',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _deleteLike(index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String type) {
    final bool isSelected = _filterType == type;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _filterType = type;
          _applyFilter();
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.green : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
      ),
      child: Text(type),
    );
  }
}





