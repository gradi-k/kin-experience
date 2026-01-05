import 'dart:ui';
import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../localization/app_localizations.dart';

/// Barre de navigation inférieure avec effet de flou (glassmorphism).
/// Elle accepte un index sélectionné et une fonction de rappel pour
/// informer le parent lors du changement d’onglet.
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
    final loc = AppLocalizations.of(context)!;
    // On construit dynamiquement la liste d'items pour permettre la localisation
    final items = [
      BottomNavigationBarItem(
        icon: const Icon(Icons.explore),
        label: loc.translate('nav_explore'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.favorite_border),
        label: loc.translate('nav_favorites'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline),
        label: loc.translate('nav_profile'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.settings_outlined),
        label: loc.translate('nav_settings'),
      ),
    ];
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onChanged,
          elevation: 0,
          backgroundColor: theme.bottomNavigationBarTheme.backgroundColor,
          selectedItemColor: theme.bottomNavigationBarTheme.selectedItemColor,
          unselectedItemColor:
              theme.bottomNavigationBarTheme.unselectedItemColor,
          items: items,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}