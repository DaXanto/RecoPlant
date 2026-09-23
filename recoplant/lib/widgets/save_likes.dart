import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Retourne le fichier JSON qui stocke les likes
Future<File> getLocalLikesFile() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/likes.json');

  // Crée le fichier vide s'il n'existe pas
  if (!await file.exists()) {
    await file.writeAsString(jsonEncode([]), flush: true);
  }

  return file;
}

/// Sauvegarde une image avec son label et sa confiance dans le fichier likes.json
Future<void> saveLike(
    BuildContext context,
    File imageFile,
    String label,
    double confidence, {
      String type = "plant", // plant ou disease
    }) async {
  try {
    final likesFile = await getLocalLikesFile();
    List<Map<String, dynamic>> likes = [];

    // Lire les données existantes
    final content = await likesFile.readAsString();
    likes = (jsonDecode(content) as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();

    // Copier l'image dans le dossier local
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final newImagePath = '${dir.path}/like_$timestamp.jpg';
    await imageFile.copy(newImagePath);

    // Ajouter la nouvelle entrée
    likes.add({
      "image_path": newImagePath,
      "label": label,
      "confidence": confidence,
      "type": type, // <-- nouveau champ
    });

    await likesFile.writeAsString(jsonEncode(likes), flush: true);
    print("✅ Saved like: $label ($type)");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Saved to Likes!"),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    print("❌ Error saving like: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Failed to save like."),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<List<Map<String, dynamic>>> loadLikes() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final likesFile = File('${dir.path}/likes.json');

    if (await likesFile.exists()) {
      final content = await likesFile.readAsString();
      return (jsonDecode(content) as List).map((e) => e as Map<String, dynamic>).toList();
    }
  } catch (e) {
    print("❌ Error loading likes: $e");
  }
  return [];
}
