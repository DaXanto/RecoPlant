// plant_shop_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:recoplant/templates/top_bar.dart';
import 'package:recoplant/widgets/animated_gradient_button.dart';
import 'package:recoplant/utils/auth_service.dart';
import 'package:recoplant/utils/firebase_service.dart';
import 'package:recoplant/widgets/circle_points.dart';

class PlantShopPage extends StatefulWidget {
  const PlantShopPage({super.key});

  @override
  State<PlantShopPage> createState() => _PlantShopPageState();
}

class _PlantShopPageState extends State<PlantShopPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Catalogue local (tu peux remplacer par une collection Firestore si tu veux)
  final List<Map<String, dynamic>> _catalog = [
    {
      'id': 'tree_small',
      'title': 'Arbre local',
      'description': 'Planter un petit arbre local.',
      'cost': 50,
      'image': 'assets/catalogue/tree_small.png',
      // optionnel, remplace si absent
    },
    {
      'id': 'tree_medium',
      'title': 'Arbre standard',
      'description': 'Planter un bel arbre qui aide la biodiversité.',
      'cost': 100,
      'image': 'assets/catalogue/tree_medium.png',
    },
    {
      'id': 'forest_packet',
      'title': 'Forêt (5 arbres)',
      'description': 'Pack de 5 arbres pour un plus grand impact.',
      'cost': 450,
      'image': 'assets/catalogue/forest_packet.png',
    },
  ];

  String _userId = '';
  int _currentPoints = 0;
  bool _loading = true;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;

  @override
  void initState() {
    super.initState();
    _initUserStream();
  }

  void _initUserStream() {
    final user = userService.currentUser;
    if (user == null) {
      setState(() {
        _userId = '';
        _currentPoints = 0;
        _loading = false;
        _userStream = null;
      });
      return;
    }
    _userId = user.uid;
    _userStream = _firestore.collection('users').doc(_userId).snapshots();
    // listen to update local points when stream emits
    _userStream!.listen((doc) {
      if (!mounted) return;
      final data = doc.data();
      setState(() {
        _currentPoints = (data != null && data['points'] is int)
            ? data['points'] as int
            : (data != null && data['points'] is num ? (data['points'] as num)
            .toInt() : 0);
        _loading = false;
      });
    }, onError: (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur récupération points : $e'),
            backgroundColor: Colors.red),
      );
    });
  }

  Future<void> _redeemItem(Map<String, dynamic> item) async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour dépenser des points.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final int cost = (item['cost'] is int)
        ? item['cost'] as int
        : (item['cost'] as num).toInt();
    if (_currentPoints < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Points insuffisants.'), backgroundColor: Colors.red),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) =>
          AlertDialog(
            title: Text(
                'Confirmer l’échange', style: GoogleFonts.playfairDisplay()),
            content: Text('Dépenser $cost points pour "${item['title']}" ?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annuler')),
              ElevatedButton(onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Confirmer')),
            ],
          ),
    );

    if (confirm != true) return;

    // Make atomic update: create order doc + decrement user points using a batch/transaction
    final String uid = _auth.currentUser!.uid;
    final WriteBatch batch = _firestore.batch();
    final orderRef = _firestore.collection('plant_orders').doc();
    final userRef = _firestore.collection('users').doc(uid);

    final orderPayload = {
      'userId': uid,
      'itemId': item['id'],
      'title': item['title'],
      'cost': cost,
      'status': 'requested',
      // possible statuses: requested, processing, planted, cancelled
      'createdAt': FieldValue.serverTimestamp(),
      // optional: store contact/shipping / geo / partner info later
    };

    try {
      // Note: using transaction to ensure points non-negative (avoid race)
      await _firestore.runTransaction((tx) async {
        final userSnap = await tx.get(userRef);
        final userData = userSnap.data();
        if (userData == null) throw Exception('Utilisateur introuvable.');
        final currentPoints = (userData['points'] is int)
            ? userData['points'] as int
            : (userData['points'] is num
            ? (userData['points'] as num).toInt()
            : 0);
        if (currentPoints < cost) throw Exception(
            'Points insuffisants lors de la validation.');

        tx.set(orderRef, orderPayload);
        tx.update(userRef, {'points': FieldValue.increment(-cost)});
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Commande enregistrée — $cost points dépensés.'),
            backgroundColor: Colors.green),
      );

      // Optionnel : appeler une Cloud Function / webhook via firebaseService pour notifier partenaire
      // ex: await firebaseService.notifyPartnerForPlanting(orderRef.id);

    } catch (e) {
      print('Erreur redemption: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l’échange : $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildCatalogCard(Map<String, dynamic> item) {
    final int cost = (item['cost'] is int)
        ? item['cost'] as int
        : (item['cost'] as num).toInt();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // image if asset exists
            if (item['image'] != null)
              SizedBox(
                height: 100,
                child: Image.asset(item['image'], fit: BoxFit.contain),
              ),
            const SizedBox(height: 8),
            Text(item['title'], style: GoogleFonts.playfairDisplay(
                fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(item['description'], textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$cost pts',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: () => _redeemItem(item),
                  child: const Text('Planter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0D9),
      body: SafeArea(
        child: SingleChildScrollView( // <-- rend la colonne scrollable
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopBar(),
                const SizedBox(height: 8),

                _loading
                    ? const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                )
                    : UserPointsHeader(points: _currentPoints),
                const SizedBox(height: 16),

                // Section scrollable interne si tu as beaucoup d’éléments
                GridView.builder(
                  shrinkWrap: true,
                  // <-- permet de s’adapter à la taille du contenu
                  physics: const NeverScrollableScrollPhysics(),
                  // <-- évite le scroll double
                  itemCount: _catalog.length,
                  padding: const EdgeInsets.only(bottom: 12, top: 4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    childAspectRatio: 1.4,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final item = _catalog[index];
                    return _buildCatalogCard(item);
                  },
                ),

                const SizedBox(height: 8),
                Center(
                  child: AnimatedGradientButton(
                    icon: Icons.history,
                    label: "Mes commandes",
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PlantOrdersPage()),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
/// Page simple pour afficher l'historique des plant_orders de l'utilisateur
class PlantOrdersPage extends StatelessWidget {
  const PlantOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = userService.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mes plantations')),
        body: const Center(child: Text('Connecte-toi pour voir ton historique.')),
      );
    }

    final Stream<QuerySnapshot> ordersStream = FirebaseFirestore.instance
        .collection('plant_orders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Mes plantations')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: ordersStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text('Aucune commande pour le moment.'));
            final docs = snap.data!.docs;
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                final title = d['title'] ?? d['itemId'] ?? 'Item';
                final cost = d['cost'] ?? 0;
                final status = d['status'] ?? 'requested';
                final ts = d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : null;
                return ListTile(
                  leading: const Icon(Icons.park),
                  title: Text(title),
                  subtitle: Text('Coût: $cost pts • Statut: $status'),
                  trailing: ts != null ? Text('${ts.day}/${ts.month}/${ts.year}') : null,
                );
              },
              separatorBuilder: (_, __) => const Divider(),
              itemCount: docs.length,
            );
          },
        ),
      ),
    );
  }
}
