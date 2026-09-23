// user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Inscription utilisateur avec email, mot de passe et displayName
  /// Crée automatiquement un document dans Firestore `users/{uid}`
  Future<User?> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        // Mise à jour du displayName dans FirebaseAuth
        await user.updateDisplayName(displayName.trim());

        // Création du document Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'email': email.trim(),
          'displayName': displayName.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'points': 0,
        });

        // Recharger l'utilisateur pour obtenir les infos à jour
        await user.reload();
        return _auth.currentUser;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('❌ Erreur inscription : ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Erreur inscription : $e');
      rethrow;
    }
  }

  /// Connexion utilisateur avec email et mot de passe
  Future<User?> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      print('❌ Erreur login : ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Erreur login : $e');
      rethrow;
    }
  }

  /// Déconnexion utilisateur
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Récupère les infos de l'utilisateur courant depuis Firestore
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  /// Met à jour les infos de l'utilisateur courant
  Future<void> updateCurrentUser({
    String? displayName,
    int? points,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final Map<String, dynamic> updateData = {};
    if (displayName != null) {
      updateData['displayName'] = displayName;
      await user.updateDisplayName(displayName);
    }
    if (points != null) updateData['points'] = points;

    if (updateData.isNotEmpty) {
      await _firestore.collection('users').doc(user.uid).update(updateData);
    }
  }

  /// Retourne l'utilisateur courant FirebaseAuth
  User? get currentUser => _auth.currentUser;

  /// Stream de l'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}

final userService = UserService();