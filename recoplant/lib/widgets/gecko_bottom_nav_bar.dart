import 'package:flutter/material.dart';

class GeckoBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final Color navBarColor;

  const GeckoBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.navBarColor,
  });

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.home_outlined,
      Icons.coronavirus_outlined,
      Icons.favorite_border,
      Icons.energy_savings_leaf_outlined,
    ];

    // Récupérer le padding en bas (pour les téléphones avec barre de navigation)
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      // SOLUTION : Ajouter une couleur de fond qui correspond à votre thème
      color: const Color(0xFFE8F0D9), // même couleur que votre Scaffold
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // === Gecko animé ===
          LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              const horizontalMargin = 20.0;
              const horizontalPadding = 25.0;
              const geckoWidth = 50.0;

              final effectiveWidth = totalWidth - (horizontalMargin * 2) - (horizontalPadding * 2);
              final itemWidth = effectiveWidth / icons.length;

              final geckoLeft =
                  horizontalMargin + horizontalPadding + (itemWidth * currentIndex) + (itemWidth / 2) - (geckoWidth / 2) - (MediaQuery.of(context).size.width * 0.035);

              return SizedBox(
                height: 36,
                width: double.infinity,
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      left: geckoLeft,
                      top: 0,
                      child: Image.asset(
                        'assets/images/gecko.png',
                        height: geckoWidth,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // === Barre de navigation ===
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 0),
            decoration: BoxDecoration(
              color: navBarColor,
              borderRadius: BorderRadius.circular(40),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(icons.length, (index) {
                final isActive = currentIndex == index;
                return IconButton(
                  onPressed: () => onTap(index),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: isActive
                        ? const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    )
                        : null,
                    child: Icon(
                      icons[index],
                      color: isActive ? navBarColor : Colors.white,
                      size: 32,
                    ),
                  ),
                );
              }),
            ),
          ),

          // SOLUTION : Ajouter un espacement en bas pour les téléphones avec barre de navigation
          SizedBox(height: bottomPadding > 0 ? bottomPadding : 10),
        ],
      ),
    );
  }
}




