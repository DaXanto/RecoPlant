// templates/top_bar.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:recoplant/pages/auth_page.dart';
import 'package:recoplant/pages/Main_page.dart';

class TopBar extends StatefulWidget implements PreferredSizeWidget {
  const TopBar({super.key});

  @override
  State<TopBar> createState() => _TopBarState();

  @override
  Size get preferredSize => const Size.fromHeight(70);
}

class _TopBarState extends State<TopBar> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Récupère le document Firestore ou crée un document par défaut si absent
  Future<Map<String, dynamic>> _fetchOrCreateUserDoc(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await docRef.get();

    if (docSnapshot.exists && docSnapshot.data() != null) {
      return docSnapshot.data()!;
    } else {
      // Création d'un document par défaut
      final defaultData = {
        'displayName': user.displayName ?? 'Utilisateur',
        'email': user.email ?? '',
        'points': 0,
      };
      await docRef.set(defaultData);
      return defaultData;
    }
  }

  void _openAccountSheet(BuildContext context, User user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.38,
          minChildSize: 0.2,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF9FFF2),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: FutureBuilder<Map<String, dynamic>>(
                future: _fetchOrCreateUserDoc(user),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snap.data!;
                  final displayName = user.displayName?.isNotEmpty ?? false
                      ? user.displayName!
                      : data['displayName']?.toString() ?? 'Utilisateur';
                  final email = user.email ?? data['email']?.toString() ?? '';
                  final points = data['points'] is int
                      ? data['points'] as int
                      : int.tryParse(data['points']?.toString() ?? '0') ?? 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Grab bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: const Color(0xFF7BAF7B),
                            child: Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayName,
                                    style: GoogleFonts.playfairDisplay(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF2E4B2E))),
                                const SizedBox(height: 4),
                                Text(email,
                                    style: TextStyle(
                                        color: Colors.grey[700], fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6E9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                const Text('Points',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF4A774A))),
                                Text(points.toString(),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF4A774A))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 8),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.person, color: Color(0xFF4A774A)),
                        title: const Text('Voir le profil'),
                        subtitle: const Text('Voir et éditer vos informations'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MainPage()));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Color(0xFFB03A2E)),
                        title: const Text('Se déconnecter'),
                        subtitle: const Text('Retour à la page d\'accueil'),
                        onTap: () async {
                          await _auth.signOut();
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Déconnecté')));

                            Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const AuthPage()));
                          }
                        },
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text('Connecté via Firebase',
                            style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          color: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  if (user == null) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AuthPage()));
                  } else {
                    _openAccountSheet(context, user);
                  }
                },
                child:
                const Icon(Icons.account_circle, color: Colors.white, size: 50),
              ),
            ],
          ),
        );
      },
    );
  }
}


