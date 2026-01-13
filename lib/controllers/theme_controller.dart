import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Un [StateNotifier] qui gère le thème actuel de l’application.
/// La valeur d’état est un [ThemeMode], qui peut être [ThemeMode.light],
/// [ThemeMode.dark] ou [ThemeMode.system].  Ce contrôleur expose
/// une méthode [toggle] permettant de basculer entre clair et sombre.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  /// Bascule entre le thème clair et le thème sombre.  Si le thème
  /// actuel est système, on passe en sombre ; sinon on inverse.
  void toggle() {
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.dark;
    }
  }

  /// Définit explicitement le thème.
  void setTheme(ThemeMode mode) {
    state = mode;
  }
}

/// Provider exposant le [ThemeModeNotifier].  Il peut être lu pour
/// obtenir le thème actuel et notifié pour déclencher un rebuild.
final themeModeProvider =
StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});