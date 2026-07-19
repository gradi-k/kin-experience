import 'package:flutter/material.dart';

/// Table de correspondance nom d'icône → [IconData].
///
/// Firestore ne peut pas stocker un [IconData] : une catégorie stocke un nom
/// (ex: "local_pharmacy") que cette table résout. C'est la seule partie du
/// système de catégories qui vit dans le code — ajouter une catégorie ne
/// demande pas d'y toucher tant que l'icône voulue est dans la liste.
///
/// Les icônes doivent être référencées en constantes (et non via
/// `IconData(codePoint)`) pour survivre au tree-shaking des polices d'icônes.
class CategoryIcons {
  const CategoryIcons._();

  /// Icône utilisée quand le nom stocké est absent de la table.
  static const IconData fallback = Icons.place;

  /// Nom d'icône par défaut pour une nouvelle catégorie.
  static const String fallbackName = 'place';

  static const Map<String, IconData> _byName = {
    // Catégories historiques
    'restaurant': Icons.restaurant,
    'hotel': Icons.hotel,
    'event': Icons.event,
    'place': Icons.place,
    'business': Icons.business,
    'shopping_bag': Icons.shopping_bag,

    // Santé
    'local_pharmacy': Icons.local_pharmacy,
    'local_hospital': Icons.local_hospital,
    'medical_services': Icons.medical_services,
    'healing': Icons.healing,
    'vaccines': Icons.vaccines,
    'monitor_heart': Icons.monitor_heart,

    // Éducation
    'school': Icons.school,
    'menu_book': Icons.menu_book,
    'science': Icons.science,
    'child_care': Icons.child_care,
    'local_library': Icons.local_library,

    // Culte
    'church': Icons.church,
    'mosque': Icons.mosque,
    'temple_buddhist': Icons.temple_buddhist,
    'synagogue': Icons.synagogue,

    // Vie nocturne
    'nightlife': Icons.nightlife,
    'local_bar': Icons.local_bar,
    'sports_bar': Icons.sports_bar,
    'music_note': Icons.music_note,
    'theater_comedy': Icons.theater_comedy,
    'celebration': Icons.celebration,

    // Beauté
    'content_cut': Icons.content_cut,
    'face_retouching_natural': Icons.face_retouching_natural,
    'spa': Icons.spa,
    'brush': Icons.brush,

    // Auto
    'car_repair': Icons.car_repair,
    'local_gas_station': Icons.local_gas_station,
    'directions_car': Icons.directions_car,
    'ev_station': Icons.ev_station,
    'local_car_wash': Icons.local_car_wash,
    'two_wheeler': Icons.two_wheeler,

    // Argent
    'account_balance': Icons.account_balance,
    'atm': Icons.atm,
    'payments': Icons.payments,
    'currency_exchange': Icons.currency_exchange,
    'savings': Icons.savings,
    'credit_card': Icons.credit_card,

    // Services publics
    'gavel': Icons.gavel,
    'local_police': Icons.local_police,
    'local_post_office': Icons.local_post_office,
    'flag': Icons.flag,
    'badge': Icons.badge,
    'local_fire_department': Icons.local_fire_department,

    // Sport
    'fitness_center': Icons.fitness_center,
    'sports_soccer': Icons.sports_soccer,
    'pool': Icons.pool,
    'sports_tennis': Icons.sports_tennis,
    'directions_run': Icons.directions_run,

    // Travail
    'business_center': Icons.business_center,
    'laptop_mac': Icons.laptop_mac,
    'groups': Icons.groups,
    'meeting_room': Icons.meeting_room,
    'print': Icons.print,

    // Divers
    'local_cafe': Icons.local_cafe,
    'bakery_dining': Icons.bakery_dining,
    'local_grocery_store': Icons.local_grocery_store,
    'storefront': Icons.storefront,
    'local_laundry_service': Icons.local_laundry_service,
    'pets': Icons.pets,
    'local_florist': Icons.local_florist,
    'photo_camera': Icons.photo_camera,
    'wifi': Icons.wifi,
    'phone_android': Icons.phone_android,
    'directions_bus': Icons.directions_bus,
    'local_airport': Icons.local_airport,
    'beach_access': Icons.beach_access,
    'park': Icons.park,
    'museum': Icons.museum,
    'attractions': Icons.attractions,
    'hardware': Icons.hardware,
    'construction': Icons.construction,
  };

  /// Résout un nom stocké en Firestore. Retourne [fallback] si inconnu.
  static IconData resolve(String? name) {
    if (name == null) return fallback;
    return _byName[name.trim()] ?? fallback;
  }

  /// Tous les noms disponibles, pour le sélecteur d'icône de l'admin.
  static List<String> get allNames => _byName.keys.toList(growable: false);

  /// Entrées (nom, icône), pour le sélecteur d'icône de l'admin.
  static List<MapEntry<String, IconData>> get all =>
      _byName.entries.toList(growable: false);

  static bool isKnown(String? name) =>
      name != null && _byName.containsKey(name.trim());
}
