import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onChanged;
  final ValueChanged<int>? onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    this.onChanged,
    this.onTap,
  });

  void _handleTap(int index) {
    if (onChanged != null) {
      onChanged!(index);
    } else if (onTap != null) {
      onTap!(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        final isTablet = w >= 600;
        final isLarge = w >= 900;

        // Taille d’icône (OK tablette)
        final double iconSize = isLarge
            ? 28
            : isTablet
            ? 26
            : 24;

        // Padding vertical des icônes (clé pour éviter l’overflow)
        final double vPad = isLarge
            ? 2
            : isTablet
            ? 3
            : 6;

        // Centrer sur grand écran sans "deux fonds"
        final double horizontalInset =
        isLarge ? (w * 0.18).clamp(0, 220) : 0;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalInset),
            child: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: _handleTap,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              backgroundColor:
              theme.bottomNavigationBarTheme.backgroundColor ??
                  theme.scaffoldBackgroundColor,
              selectedItemColor:
              theme.bottomNavigationBarTheme.selectedItemColor,
              unselectedItemColor:
              theme.bottomNavigationBarTheme.unselectedItemColor,
              iconSize: iconSize,
              items: [
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.symmetric(vertical: vPad),
                    child: const Icon(Icons.explore_outlined),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.symmetric(vertical: vPad),
                    child: const Icon(Icons.explore),
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.symmetric(vertical: vPad),
                    child: const Icon(Icons.play_circle_outline),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.symmetric(vertical: vPad),
                    child: const Icon(Icons.play_circle_filled),
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.symmetric(vertical: vPad),
                    child: const Icon(Icons.search),
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.symmetric(vertical: vPad),
                    child: const Icon(Icons.person_outline),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.symmetric(vertical: vPad),
                    child: const Icon(Icons.person),
                  ),
                  label: '',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
