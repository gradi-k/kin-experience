import 'dart:ui';
import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../localization/app_localizations.dart';
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const BottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.explore_outlined),
        activeIcon: Icon(Icons.explore),
        label: '', // Obligatoire mais caché
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.play_circle_outline),
        activeIcon: Icon(Icons.play_circle_filled),
        label: '',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.search),
        label: '',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: '',
      ),
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onChanged,
          elevation: 0,
          // ✅ Désactive l'affichage des textes
          showSelectedLabels: false,
          showUnselectedLabels: false,
          // ✅ Ajuste la taille des icônes pour un look plus "Premium"
          iconSize: 28,
          backgroundColor: theme.bottomNavigationBarTheme.backgroundColor?.withOpacity(0.8),
          selectedItemColor: theme.bottomNavigationBarTheme.selectedItemColor,
          unselectedItemColor: theme.bottomNavigationBarTheme.unselectedItemColor,
          items: items,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}
