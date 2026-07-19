// lib/controllers/locale_controller.dart
import 'dart:ui';

import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gère la langue de l'application (fr / en), persistée en SharedPreferences.
class LocaleNotifier extends StateNotifier<Locale> {
  static const String kLocaleKey = 'app_locale';

  LocaleNotifier() : super(const Locale('fr', 'FR')) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(kLocaleKey);
      if (code == 'en') {
        state = const Locale('en', 'US');
      } else if (code == 'fr') {
        state = const Locale('fr', 'FR');
      }
    } catch (_) {
      // On garde le français par défaut.
    }
  }

  Future<void> setLocale(String languageCode) async {
    state = languageCode == 'en'
        ? const Locale('en', 'US')
        : const Locale('fr', 'FR');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kLocaleKey, languageCode);
    } catch (_) {}
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
