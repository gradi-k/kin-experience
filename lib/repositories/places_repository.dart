import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

import '../models/place_enums.dart';

/// Modèle minimaliste aligné sur les écrans:
/// - add_content_form.dart
/// - edit_content_from.dart
/// - edit_draft_form.dart
///
/// Les champs "métier" (rating, prixRange, etc.) sont stockés dans [meta].
class PlaceItem {
  final String id;
  final String nom;
  final String description;
  final String address;
  final List<String> photos;
  final GeoPoint location; // latitude/longitude
  final String category; // key de PlaceCategory (ex: "resto")
  final Map<String, dynamic> meta;

  const PlaceItem({
    required this.id,
    required this.nom,
    required this.description,
    required this.address,
    required this.photos,
    required this.location,
    required this.category,
    required this.meta,
  });

  /// Helpers (facultatifs) pour éviter des null-checks partout.
  double get rating {
    final v = meta['rating'];
    if (v is num) return v.toDouble();
    return 0.0;
  }

  String get prixRange => (meta['prixRange'] ?? '').toString();

  List<String> get amenities {
    final v = meta['amenities'];
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  Map<String, dynamic> get schedule {
    final v = meta['schedule'];
    if (v is Map<String, dynamic>) return v;
    return const {};
  }

  List<String> get keywords {
    final v = meta['keywords'];
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  bool get isFeatured {
    final v = meta['isFeatured'];
    if (v is bool) return v;
    return false;
  }

  String get phone => (meta['phone'] ?? '').toString();
  String get email => (meta['email'] ?? '').toString();
  String get website => (meta['website'] ?? '').toString();
  String get facebookUrl => (meta['facebookUrl'] ?? '').toString();
  String get instagramUrl => (meta['instagramUrl'] ?? '').toString();
  String get tiktokUrl => (meta['tiktokUrl'] ?? '').toString();

  PlaceItem copyWith({
    String? id,
    String? nom,
    String? description,
    String? address,
    List<String>? photos,
    GeoPoint? location,
    String? category,
    Map<String, dynamic>? meta,
  }) {
    return PlaceItem(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      address: address ?? this.address,
      photos: photos ?? this.photos,
      location: location ?? this.location,
      category: category ?? this.category,
      meta: meta ?? this.meta,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'description': description,
      'address': address,
      'photos': photos,
      'location': location,
      'category': category,
      'meta': meta,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static PlaceItem fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    GeoPoint loc;
    final rawLoc = data['location'];
    if (rawLoc is GeoPoint) {
      loc = rawLoc;
    } else if (rawLoc is Map) {
      final lat = (rawLoc['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (rawLoc['longitude'] as num?)?.toDouble() ?? 0.0;
      loc = GeoPoint(lat, lng);
    } else {
      loc = const GeoPoint(0, 0);
    }

    final rawPhotos = data['photos'];
    final photos = (rawPhotos is List) ? rawPhotos.map((e) => e.toString()).toList() : <String>[];

    final rawMeta = data['meta'];
    final meta = (rawMeta is Map<String, dynamic>) ? rawMeta : <String, dynamic>{};

    return PlaceItem(
      id: doc.id,
      nom: (data['nom'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      photos: photos,
      location: loc,
      category: (data['category'] ?? '').toString(),
      meta: meta,
    );
  }
}

class PlacesRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  PlacesRepository({
    FirebaseFirestore? db,
    FirebaseStorage? storage,
  })  : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _col(PlaceCategory category) =>
      _db.collection(category.collectionName);

  /// Stream temps réel par catégorie (utilisé dans content_list_screen.dart).
  Stream<List<PlaceItem>> watchByCategory(PlaceCategory category) {
    return _col(category).orderBy('updatedAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(PlaceItem.fromDoc).toList(),
    );
  }

  /// Stream temps réel (toutes catégories): optionnel.
  Stream<List<PlaceItem>> watchPlaces({PlaceCategory? category}) {
    if (category != null) return watchByCategory(category);
    // Si vous voulez "tout", il faut agréger plusieurs collections (non-trivial).
    // Ici, on renvoie un stream vide pour éviter une fausse promesse.
    return const Stream.empty();
  }

  Future<List<PlaceItem>> fetchPlaces(PlaceCategory category) async {
    final snap = await _col(category).orderBy('updatedAt', descending: true).get();
    return snap.docs.map(PlaceItem.fromDoc).toList();
  }

  /// Upload d'images en WEBP (ou en l'état si vous ne compressez pas avant).
  /// Retourne des URLs publiques (downloadURL).
  Future<List<String>> uploadImages({
    required String folder,
    required List<File> files,
  }) async {
    if (files.isEmpty) return <String>[];

    final out = <String>[];
    for (final file in files) {
      final ext = p.extension(file.path).isEmpty ? '.webp' : p.extension(file.path);
      final name = '${DateTime.now().millisecondsSinceEpoch}_${p.basenameWithoutExtension(file.path)}$ext';
      final ref = _storage.ref().child('$folder/$name');

      final task = await ref.putFile(file);
      final url = await task.ref.getDownloadURL();
      out.add(url);
    }
    return out;
  }

  Future<String> createPlace({
    required PlaceCategory category,
    required PlaceItem place,
    List<File> images = const [],
  }) async {
    final folder = category.collectionName;
    final urls = await uploadImages(folder: folder, files: images);

    final docRef = _col(category).doc();
    await docRef.set({
      ...place.toMap(),
      'photos': urls,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updatePlace({
    required PlaceCategory category,
    required String id,
    required PlaceItem updated,
    List<File> newImages = const [],
    bool replacePhotos = false,
  }) async {
    final docRef = _col(category).doc(id);

    List<String> photos = updated.photos;
    if (newImages.isNotEmpty) {
      final folder = category.collectionName;
      final urls = await uploadImages(folder: folder, files: newImages);
      photos = replacePhotos ? urls : [...updated.photos, ...urls];
    }

    await docRef.update({
      ...updated.toMap(),
      'photos': photos,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePlace({
    required PlaceCategory category,
    required String id,
  }) async {
    await _col(category).doc(id).delete();
  }
}
