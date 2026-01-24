import 'package:flutter/material.dart';

/// Catégories de contenus (lieux) gérées par l'application.
///
/// IMPORTANT:
/// - Les valeurs (resto, hotel, ...) sont utilisées comme "keys" pour:
///   1) nommer les collections Firestore
///   2) sérialiser / désérialiser les documents
enum PlaceCategory {
  resto,
  hotel,
  event,
  site,
  entreprise,
  shopping,
}

extension PlaceCategoryX on PlaceCategory {
  /// Clé stable (utilisée dans Firestore / routes / paramètres).
  String get key => name;

  /// Récupère une catégorie depuis une clé (tolère quelques alias).
  static PlaceCategory fromKey(String key) {
    final k = key.trim().toLowerCase();
    switch (k) {
      case 'resto':
      case 'restaurant':
      case 'restaurants':
        return PlaceCategory.resto;

      case 'hotel':
      case 'hotels':
        return PlaceCategory.hotel;

      case 'event':
      case 'events':
      case 'evenement':
      case 'evenements':
        return PlaceCategory.event;

      case 'site':
      case 'sites':
        return PlaceCategory.site;

      case 'entreprise':
      case 'business':
      case 'company':
        return PlaceCategory.entreprise;

      case 'shopping':
      case 'market':
      case 'shop':
        return PlaceCategory.shopping;

      default:
      // fallback raisonnable
        return PlaceCategory.site;
    }
  }

  /// Libellé pour l'UI.
  String get label {
    switch (this) {
      case PlaceCategory.resto:
        return 'Restaurants';
      case PlaceCategory.hotel:
        return 'Hôtels';
      case PlaceCategory.event:
        return 'Événements';
      case PlaceCategory.site:
        return 'Sites';
      case PlaceCategory.entreprise:
        return 'Business';
      case PlaceCategory.shopping:
        return 'Market';
    }
  }

  /// Icône pour l'UI (optionnel).
  IconData get icon {
    switch (this) {
      case PlaceCategory.resto:
        return Icons.restaurant;
      case PlaceCategory.hotel:
        return Icons.hotel;
      case PlaceCategory.event:
        return Icons.event;
      case PlaceCategory.site:
        return Icons.place;
      case PlaceCategory.entreprise:
        return Icons.business;
      case PlaceCategory.shopping:
        return Icons.shopping_bag;
    }
  }

  /// Nom de collection Firestore
  String get collectionName {
    switch (this) {
      case PlaceCategory.resto:
        return 'restaurants';
      case PlaceCategory.hotel:
        return 'hotels';
      case PlaceCategory.event:
        return 'events';
      case PlaceCategory.site:
        return 'sites';
      case PlaceCategory.entreprise:
        return 'business';
      case PlaceCategory.shopping:
        return 'shopping';
    }
  }
}