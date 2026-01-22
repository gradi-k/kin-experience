import 'package:flutter/material.dart';

/// Catégories officielles + alias legacy pour éviter de casser les anciens écrans.
enum PlaceCategory {
  // ✅ Officielles (à utiliser à l’avenir)
  sites,
  restaurants,
  hotels,
  events,
  business,
  shopping,

  // ⚠️ Alias legacy (encore utilisés dans certaines pages)
  site,
  resto,
  hotel,
  event,
  entreprise,
}

extension PlaceCategoryX on PlaceCategory {
  /// Convertit les alias legacy vers les catégories officielles
  PlaceCategory get canonical {
    switch (this) {
      case PlaceCategory.site:
        return PlaceCategory.sites;
      case PlaceCategory.resto:
        return PlaceCategory.restaurants;
      case PlaceCategory.hotel:
        return PlaceCategory.hotels;
      case PlaceCategory.event:
        return PlaceCategory.events;
      case PlaceCategory.entreprise:
        return PlaceCategory.business;

    // Déjà canonical
      case PlaceCategory.sites:
      case PlaceCategory.restaurants:
      case PlaceCategory.hotels:
      case PlaceCategory.events:
      case PlaceCategory.business:
      case PlaceCategory.shopping:
        return this;
    }
  }

  /// Nom de collection (Firestore / DB)
  String get collectionName {
    switch (canonical) {
      case PlaceCategory.sites:
        return 'sites';
      case PlaceCategory.restaurants:
        return 'restos';
      case PlaceCategory.hotels:
        return 'hotels';
      case PlaceCategory.events:
        return 'events';
      case PlaceCategory.business:
        return 'entreprises';
      case PlaceCategory.shopping:
        return 'shopping';
    // legacy couvert par canonical
      case PlaceCategory.site:
      case PlaceCategory.resto:
      case PlaceCategory.hotel:
      case PlaceCategory.event:
      case PlaceCategory.entreprise:
        return canonical.collectionName;
    }
  }

  /// Libellé (pour UI)
  String get label {
    switch (canonical) {
      case PlaceCategory.sites:
        return 'Sites';
      case PlaceCategory.restaurants:
        return 'Restaurants';
      case PlaceCategory.hotels:
        return 'Hôtels';
      case PlaceCategory.events:
        return 'Événements';
      case PlaceCategory.business:
        return 'Business';
      case PlaceCategory.shopping:
        return 'Shopping';
    // legacy couvert par canonical
      case PlaceCategory.site:
      case PlaceCategory.resto:
      case PlaceCategory.hotel:
      case PlaceCategory.event:
      case PlaceCategory.entreprise:
        return canonical.label;
    }
  }

  IconData get icon {
    switch (canonical) {
      case PlaceCategory.sites:
        return Icons.location_city_outlined;
      case PlaceCategory.restaurants:
        return Icons.restaurant_outlined;
      case PlaceCategory.hotels:
        return Icons.hotel_outlined;
      case PlaceCategory.events:
        return Icons.event_outlined;
      case PlaceCategory.business:
        return Icons.business_center_outlined;
      case PlaceCategory.shopping:
        return Icons.shopping_bag_outlined;
    // legacy couvert par canonical
      case PlaceCategory.site:
      case PlaceCategory.resto:
      case PlaceCategory.hotel:
      case PlaceCategory.event:
      case PlaceCategory.entreprise:
        return canonical.icon;
    }
  }
}

/// Utilise ceci pour les menus (évite d’afficher les alias legacy)
const List<PlaceCategory> primaryCategories = [
  PlaceCategory.sites,
  PlaceCategory.restaurants,
  PlaceCategory.hotels,
  PlaceCategory.events,
  PlaceCategory.business,
  PlaceCategory.shopping,
];
