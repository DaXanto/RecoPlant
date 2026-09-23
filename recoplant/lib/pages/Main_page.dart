import 'package:flutter/material.dart';
import 'package:recoplant/pages/home_page.dart';
import 'package:recoplant/pages/disease_page.dart';
import 'package:recoplant/pages/like_page.dart';
import 'package:recoplant/widgets/gecko_bottom_nav_bar.dart';
import 'package:recoplant/pages/points_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    HomePage(),
    DiseaseDetectionPage(),
    LikesPage(),
    PlantShopPage(),
  ];

  void onNavBarTap(int index) {
    setState(() => currentIndex = index);
  }

  final navBarColor = const Color(0xFF7CB342);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0D9),
      resizeToAvoidBottomInset: true,
      body: pages[currentIndex],
      bottomNavigationBar: GeckoBottomNavBar(
        currentIndex: currentIndex,
        onTap: onNavBarTap,
        navBarColor: navBarColor,
      ),
    );
  }
}





