import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  // bucket spécifique (ton bucket)
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'gs://recoplantapp.firebasestorage.app',
  );

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload de l'image et récupération de l'URL.
  /// Si [createPlantEntry] est true, crée aussi un document dans la collection `plants`
  /// avec le [name] et [description] fournis et renvoie l'ID du doc créé (dans returnMap['plantId']).
  Future<Map<String, dynamic>> uploadImageAndOptionallyCreatePlant({
    required File imageFile,
    bool createPlantEntry = false,
    String? name,
    String? description,
  }) async {
    try {
      final path = 'plant_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage.ref().child(path);

      final metadata = SettableMetadata(contentType: 'image/jpeg');

      final uploadTask = await storageRef.putFile(imageFile, metadata);
      // Optionnel : vérifier l'état
      if (uploadTask.state != TaskState.success) {
        throw Exception('Upload failed with state ${uploadTask.state}');
      }

      final downloadUrl = await storageRef.getDownloadURL();
      print('✅ Upload réussi : $downloadUrl');

      String? plantId;
      if (createPlantEntry) {
        if (name == null || name.trim().isEmpty) {
          throw Exception('name is required when createPlantEntry is true');
        }
        plantId = await createPlant(
          name: name,
          imageUrl: downloadUrl,
          description: description ?? '',
        );
      }

      return {
        'downloadUrl': downloadUrl,
        'plantId': plantId, // null si non créé
      };
    } catch (e) {
      print('❌ Erreur upload : $e');
      rethrow;
    }
  }

  /// Crée un document dans la collection `plants` et retourne l'ID du document créé.
  Future<String> createPlant({
    required String name,
    required String imageUrl,
    String description = '',
  }) async {
    try {
      final user = _auth.currentUser;
      final docRef = await _firestore.collection('plants').add({
        'name': name,
        'image_url': imageUrl,
        'description': description,
        'createdBy': user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        // champs additionnels si besoin
      });
      print('✅ Plant created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Erreur création plant: $e');
      rethrow;
    }
  }

  /// Sauvegarde de l'analyse dans Firestore (collection 'analyses').
  /// Ajoute userId si l'utilisateur est connecté.
  Future<void> saveAnalysis({
    required String imageUrl,
    required String label,
    required double confidence,
    required String description,
    bool isDisease = false,
    String? plantId, // facultatif : référence au document plants si pertinent
  }) async {
    try {
      final user = _auth.currentUser;
      final doc = _firestore.collection('analyses').doc();
      await doc.set({
        'image_url': imageUrl,
        'label': label,
        'confidence': confidence,
        'description': description,
        'is_disease': isDisease,
        'plantId': plantId,
        'userId': user?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('✅ Analyse sauvegardée dans Firestore: ${doc.id}');
    } catch (e) {
      print('❌ Erreur sauvegarde Firestore : $e');
      rethrow;
    }
  }
}

final firebaseService = FirebaseService();
