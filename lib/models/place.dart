import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_helpers.dart';

/// Un lieu, toutes catégories confondues, stocké dans `places/{id}`.
///
/// Remplace les 6 classes Hotel/Resto/Site/Event/Entreprise/Shopping, qui
/// étaient des copies identiques : la catégorie est désormais une donnée
/// ([categoryKey]) et non un type.
///
/// [fromMap] tolère les trois formes de documents qui coexistent en base :
///  1. flat      — `latitude`/`longitude` + champs à la racine (add_content_form)
///  2. GeoPoint  — `location` + champs métier sous `meta` (drafts publiés)
///  3. natif     — écrit par [toMap] : flat + `location` + `extras`
/// Les lieux migrés sont en forme 3 ; les deux autres restent lisibles pour
/// que la migration puisse être rejouée ou différée sans casser l'app.
class Place {
  final String id;
  final String categoryKey;

  final String nom;
  final String description;
  final double rating;
  final double latitude;
  final double longitude;
  final List<String> photos;
  final String prixRange;
  final bool isFeatured;

  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? tiktokUrl;
  final List<String> amenities;
  final String? schedule;
  final int reviewCount;
  final double distanceKm;

  final String? menuUrl;
  final String? menuType;

  /// Valeurs des champs déclarés par la catégorie (voir `CategoryConfig.fields`).
  final Map<String, dynamic> extras;

  const Place({
    required this.id,
    required this.categoryKey,
    required this.nom,
    this.description = '',
    this.rating = 0.0,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.photos = const [],
    this.prixRange = '',
    this.isFeatured = false,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.facebookUrl,
    this.instagramUrl,
    this.tiktokUrl,
    this.amenities = const [],
    this.schedule,
    this.reviewCount = 0,
    this.distanceKm = 0.0,
    this.menuUrl,
    this.menuType,
    this.extras = const {},
  });

  bool get hasLocation => latitude != 0.0 || longitude != 0.0;

  GeoPoint get geoPoint => GeoPoint(latitude, longitude);

  /// Valeur d'un champ personnalisé, `null` si absent.
  dynamic extra(String key) => extras[key];

  factory Place.fromMap(Map<String, dynamic> map, String id) {
    // `meta` : forme 2 (drafts publiés). Les champs métier y sont imbriqués.
    final meta = ModelHelpers.parseMap(map['meta']);

    // Un champ peut vivre à la racine (formes 1 et 3) ou sous `meta` (forme 2).
    dynamic pick(String key) => map[key] ?? meta[key];

    // Coordonnées : `latitude`/`longitude` plats, sinon le GeoPoint `location`.
    double lat = ModelHelpers.parseDouble(map['latitude']);
    double lng = ModelHelpers.parseDouble(map['longitude']);
    if (lat == 0.0 && lng == 0.0) {
      final rawLoc = map['location'];
      if (rawLoc is GeoPoint) {
        lat = rawLoc.latitude;
        lng = rawLoc.longitude;
      } else if (rawLoc is Map) {
        lat = ModelHelpers.parseDouble(rawLoc['latitude']);
        lng = ModelHelpers.parseDouble(rawLoc['longitude']);
      }
    }

    String? str(String key) {
      final v = pick(key);
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    // `category` est le nom historique dans les drafts ; `categoryKey` le nouveau.
    final cat = (map['categoryKey'] ?? map['category'] ?? '').toString().trim();

    return Place(
      id: id,
      categoryKey: cat,
      nom: (pick('nom') ?? '').toString(),
      description: (pick('description') ?? '').toString(),
      rating: ModelHelpers.parseDouble(pick('rating')),
      latitude: lat,
      longitude: lng,
      photos: ModelHelpers.parsePhotos(map['photos'] ?? meta['photos']),
      prixRange: (pick('prixRange') ?? '').toString(),
      isFeatured: ModelHelpers.parseBool(pick('isFeatured')),
      address: str('address'),
      phone: str('phone'),
      email: str('email'),
      website: str('website'),
      facebookUrl: str('facebookUrl'),
      instagramUrl: str('instagramUrl'),
      tiktokUrl: str('tiktokUrl'),
      amenities: ModelHelpers.parseStringList(pick('amenities')),
      schedule: str('schedule'),
      reviewCount: ModelHelpers.parseInt(pick('reviewCount')),
      distanceKm: ModelHelpers.parseDouble(pick('distanceKm')),
      menuUrl: str('menuUrl'),
      menuType: str('menuType'),
      extras: ModelHelpers.parseMap(map['extras']),
    );
  }

  factory Place.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Place.fromMap(doc.data() ?? <String, dynamic>{}, doc.id);

  /// Écrit la forme native : champs plats (compatibles avec les lecteurs
  /// existants) + `location` GeoPoint pour les requêtes géo + `extras`.
  ///
  /// N'inclut pas `createdAt`/`updatedAt` : c'est au repository de les poser,
  /// pour qu'une mise à jour n'écrase pas la date de création.
  Map<String, dynamic> toMap() {
    return {
      'categoryKey': categoryKey,
      'nom': nom,
      'description': description,
      'rating': rating,
      'latitude': latitude,
      'longitude': longitude,
      'location': GeoPoint(latitude, longitude),
      'photos': photos,
      'prixRange': prixRange,
      'isFeatured': isFeatured,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'facebookUrl': facebookUrl,
      'instagramUrl': instagramUrl,
      'tiktokUrl': tiktokUrl,
      'amenities': amenities,
      'schedule': schedule,
      'reviewCount': reviewCount,
      'distanceKm': distanceKm,
      'menuUrl': menuUrl,
      'menuType': menuType,
      'extras': extras,
    };
  }

  Place copyWith({
    String? id,
    String? categoryKey,
    String? nom,
    String? description,
    double? rating,
    double? latitude,
    double? longitude,
    List<String>? photos,
    String? prixRange,
    bool? isFeatured,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? facebookUrl,
    String? instagramUrl,
    String? tiktokUrl,
    List<String>? amenities,
    String? schedule,
    int? reviewCount,
    double? distanceKm,
    String? menuUrl,
    String? menuType,
    Map<String, dynamic>? extras,
  }) {
    return Place(
      id: id ?? this.id,
      categoryKey: categoryKey ?? this.categoryKey,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      rating: rating ?? this.rating,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photos: photos ?? this.photos,
      prixRange: prixRange ?? this.prixRange,
      isFeatured: isFeatured ?? this.isFeatured,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      tiktokUrl: tiktokUrl ?? this.tiktokUrl,
      amenities: amenities ?? this.amenities,
      schedule: schedule ?? this.schedule,
      reviewCount: reviewCount ?? this.reviewCount,
      distanceKm: distanceKm ?? this.distanceKm,
      menuUrl: menuUrl ?? this.menuUrl,
      menuType: menuType ?? this.menuType,
      extras: extras ?? this.extras,
    );
  }

  /// Texte indexé par la recherche globale.
  String get searchableText =>
      [nom, description, address ?? ''].where((s) => s.isNotEmpty).join(' ');
}
