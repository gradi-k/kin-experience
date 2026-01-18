import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/place_enums.dart';

/// Représentation générique d'un "place" provenant de Firestore.
/// On garde volontairement des noms de champs qui matchent tes anciens modèles
/// (nom, description, prixRange, photos, latitude, longitude, etc.)
class PlaceItem {
  final String id;
  final PlaceCategory category;

  final String nom;
  final String description;

  /// Note moyenne (si tu la stockes dans la collection place),
  /// sinon tu peux laisser 0.0 et calculer depuis /reviews.
  final double rating;

  /// Exemple: "$$", "$$$", etc.
  final String prixRange;

  /// Liste d'URLs (ou assets) - mais sur Firebase tu vas mettre des URLs.
  final List<String> photos;

  final double? latitude;
  final double? longitude;

  final String? address;
  final String? phone;
  final String? email;
  final String? website;

  final String? facebookUrl;
  final String? instagramUrl;
  final String? tiktokUrl;

  final List<String> amenities;
  final String? schedule;

  /// Pour la recherche (optionnel)
  final List<String> keywords;

  const PlaceItem({
    required this.id,
    required this.category,
    required this.nom,
    required this.description,
    required this.rating,
    required this.prixRange,
    required this.photos,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.phone,
    required this.email,
    required this.website,
    required this.facebookUrl,
    required this.instagramUrl,
    required this.tiktokUrl,
    required this.amenities,
    required this.schedule,
    required this.keywords,
  });

  factory PlaceItem.fromDoc({
    required PlaceCategory category,
    required DocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};

    String s(dynamic v) => (v ?? '').toString().trim();

    double d(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    double? dn(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    List<String> listStr(dynamic v) {
      if (v == null) return const [];
      if (v is List) {
        return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      }
      return const [];
    }

    return PlaceItem(
      id: doc.id,
      category: category,
      nom: s(data['nom']),
      description: s(data['description']),
      rating: d(data['rating']),
      prixRange: s(data['prixRange']),
      photos: listStr(data['photos']),
      latitude: dn(data['latitude']),
      longitude: dn(data['longitude']),
      address: s(data['address']).isEmpty ? null : s(data['address']),
      phone: s(data['phone']).isEmpty ? null : s(data['phone']),
      email: s(data['email']).isEmpty ? null : s(data['email']),
      website: s(data['website']).isEmpty ? null : s(data['website']),
      facebookUrl: s(data['facebookUrl']).isEmpty ? null : s(data['facebookUrl']),
      instagramUrl: s(data['instagramUrl']).isEmpty ? null : s(data['instagramUrl']),
      tiktokUrl: s(data['tiktokUrl']).isEmpty ? null : s(data['tiktokUrl']),
      amenities: listStr(data['amenities']),
      schedule: s(data['schedule']).isEmpty ? null : s(data['schedule']),
      keywords: listStr(data['keywords']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category.name,
      'nom': nom,
      'description': description,
      'rating': rating,
      'prixRange': prixRange,
      'photos': photos,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'facebookUrl': facebookUrl,
      'instagramUrl': instagramUrl,
      'tiktokUrl': tiktokUrl,
      'amenities': amenities,
      'schedule': schedule,
      'keywords': keywords,
    };
  }
}

class PlacesRepository {
  final FirebaseFirestore _db;
  PlacesRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Mappe ton enum vers le nom exact de collection Firestore.
  String _collectionName(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.site:
        return 'sites';
      case PlaceCategory.hotel:
        return 'hotels';
      case PlaceCategory.resto:
        return 'restos';
      case PlaceCategory.event:
        return 'events';
      case PlaceCategory.entreprise:
        return 'entreprises';
      case PlaceCategory.shopping:
        return 'shoppings';
    }
  }

  CollectionReference<Map<String, dynamic>> _col(PlaceCategory c) {
    return _db.collection(_collectionName(c));
  }

  // ---------------------------------------------------------------------------
  // 1) Fetch par catégorie (Future)
  // ---------------------------------------------------------------------------
  Future<List<PlaceItem>> fetchByCategory(
      PlaceCategory category, {
        int limit = 200,
      }) async {
    final snap = await _col(category).limit(limit).get();
    return snap.docs.map((d) => PlaceItem.fromDoc(category: category, doc: d)).toList();
  }

  // ---------------------------------------------------------------------------
  // 2) Watch par catégorie (Stream)
  // ---------------------------------------------------------------------------
  Stream<List<PlaceItem>> watchByCategory(
      PlaceCategory category, {
        int limit = 200,
      }) {
    return _col(category).limit(limit).snapshots().map(
          (snap) => snap.docs.map((d) => PlaceItem.fromDoc(category: category, doc: d)).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // 3) Global fetch (toutes catégories)
  // ---------------------------------------------------------------------------
  Future<List<PlaceItem>> fetchAll({
    List<PlaceCategory>? categories,
    int limitPerCategory = 200,
  }) async {
    final cats = categories ??
        const [
          PlaceCategory.site,
          PlaceCategory.hotel,
          PlaceCategory.resto,
          PlaceCategory.event,
          PlaceCategory.entreprise,
          PlaceCategory.shopping,
        ];

    final results = <PlaceItem>[];

    for (final c in cats) {
      final items = await fetchByCategory(c, limit: limitPerCategory);
      results.addAll(items);
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // 4) Global watch (toutes catégories)
  // IMPORTANT: Firestore ne permet pas un stream multi-collections natif.
  // Donc on garde plutôt des streams par catégorie côté UI, ou on fait un Future.
  // Ici on propose une version "Future + refresh" plutôt que stream combiné.
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // 5) Global Search (Méthode 1)
  //
  // Option A (recommandée): tu ajoutes un champ `keywords: [ ... ]` dans chaque doc
  // => query where('keywords', arrayContains: qLower)
  //
  // Fallback: si `keywords` absent, on fetch et on filtre côté app.
  // ---------------------------------------------------------------------------
  Future<List<PlaceItem>> globalSearch(
      String query, {
        List<PlaceCategory>? categories,
        int limitPerCategory = 100,
      }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return fetchAll(categories: categories, limitPerCategory: limitPerCategory);
    }

    final cats = categories ??
        const [
          PlaceCategory.site,
          PlaceCategory.hotel,
          PlaceCategory.resto,
          PlaceCategory.event,
          PlaceCategory.entreprise,
          PlaceCategory.shopping,
        ];

    final results = <PlaceItem>[];

    for (final c in cats) {
      final col = _col(c);

      // Try: server-side search if keywords exists
      // If it fails due to missing index/field, fallback to client filter.
      try {
        final snap = await col.where('keywords', arrayContains: q).limit(limitPerCategory).get();
        results.addAll(
          snap.docs.map((d) => PlaceItem.fromDoc(category: c, doc: d)).toList(),
        );
        continue;
      } catch (_) {
        // fallback below
      }

      // Fallback: download limited then filter locally
      final snap = await col.limit(limitPerCategory).get();
      final items = snap.docs.map((d) => PlaceItem.fromDoc(category: c, doc: d)).toList();

      final filtered = items.where((p) {
        final name = p.nom.toLowerCase();
        final desc = p.description.toLowerCase();
        final addr = (p.address ?? '').toLowerCase();
        return name.contains(q) || desc.contains(q) || addr.contains(q);
      }).toList();

      results.addAll(filtered);
    }

    return results;
  }


}
