import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:recoplant/pages/auth_page.dart';
import 'package:recoplant/widgets/animated_get_started_button.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3DB),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // === LOGO REC🌿PLANT ===
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "REC",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 36,
                    color: const Color(0xFF639636),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.only(top: 35),
                  width: 65,
                  height: 100,
                  alignment: Alignment.center,
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.center,
                      widthFactor: 0.80,
                      child: Image.asset(
                        'assets/images/loupe.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Text(
                  "PLANT",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 36,
                    color: const Color(0xFF639636),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // === IMAGE PRINCIPALE ===
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Image.asset(
                  'assets/images/image.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // === GECKO + BOUTON ===
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  // Bouton
                  AnimatedGetStartedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AuthPage(),
                        ),
                      );
                    },
                  ),
                  // Gecko superposé au-dessus du bouton
                  Positioned(
                    bottom: 35, // Ajuste cette valeur si le gecko semble trop haut ou bas
                    child: Image.asset(
                      'assets/images/gecko.png',
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}





