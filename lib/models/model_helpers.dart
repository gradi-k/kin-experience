// lib/models/model_helpers.dart

/// Helpers pour parser les données Firebase de manière robuste
class ModelHelpers {
  /// Parse le champ photos qui peut être:
  /// - List<dynamic> (cas normal)
  /// - String (une seule URL)
  /// - null
  static List<String> parsePhotos(dynamic value) {
    if (value == null) return const <String>[];

    // Cas 1: C'est déjà une liste
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }

    // Cas 2: C'est une String unique
    if (value is String) {
      if (value.trim().isEmpty) return const <String>[];
      return [value];
    }

    // Cas 3: Type inconnu, on essaie de convertir en String
    return [value.toString()];
  }

  /// Parse le champ amenities (même logique que photos)
  static List<String> parseStringList(dynamic value) {
    if (value == null) return const <String>[];

    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }

    if (value is String) {
      if (value.trim().isEmpty) return const <String>[];
      // Si c'est une string séparée par des virgules, on split
      if (value.contains(',')) {
        return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return [value];
    }

    return [value.toString()];
  }

  /// Parse un nombre (int ou double) de manière robuste
  static double parseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Parse un entier de manière robuste
  static int parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Parse une map de libellés localisés `{fr: "...", en: "..."}`.
  ///
  /// Tolère une String simple (anciens documents non localisés), auquel cas
  /// la valeur est rangée sous 'fr' (locale par défaut de l'app).
  static Map<String, String> parseLocalizedString(dynamic value) {
    if (value == null) return const <String, String>{};

    if (value is Map) {
      final out = <String, String>{};
      value.forEach((k, v) {
        if (v != null && v.toString().trim().isNotEmpty) {
          out[k.toString()] = v.toString();
        }
      });
      return out;
    }

    if (value is String) {
      if (value.trim().isEmpty) return const <String, String>{};
      return {'fr': value};
    }

    return {'fr': value.toString()};
  }

  /// Parse une map libre (ex: `meta`, `extras`) en tolérant les
  /// `Map<dynamic, dynamic>` que renvoie parfois le cache Firestore.
  static Map<String, dynamic> parseMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  /// Parse un boolean de manière robuste
  static bool parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    if (value is int) return value != 0;
    return defaultValue;
  }
}