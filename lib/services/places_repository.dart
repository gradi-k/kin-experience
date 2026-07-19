// lib/services/places_repository.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cityguide/models/place.dart';
import 'package:cityguide/services/image_service.dart';

/// Repository unique de la collection `places`.
///
/// Remplace les 6 collections par catégorie : une catégorie est maintenant la
/// valeur du champ `categoryKey`, ce qui rend le nombre de catégories sans
/// effet sur le code. La home lit un seul stream au lieu d'en combiner six.
class PlacesRepository {
  final FirebaseFirestore _firestore;

  PlacesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String collectionName = 'places';

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(collectionName);

  List<Place> _map(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map(Place.fromDoc).toList();

  /// Base des requêtes publiques : uniquement les lieux publiés.
  ///
  /// `isEqualTo: false` et non `isNotEqualTo: true` : une requête `!=` ne
  /// renvoie que les documents où le champ EXISTE, ce qui masquerait tout
  /// document sans `isDraft`. Le script de migration pose donc `isDraft:
  /// false` explicitement sur chaque lieu publié.
  ///
  /// Les règles Firestore refusent la lecture d'un brouillon à un
  /// non-admin : ce filtre n'est pas qu'une commodité d'affichage, il rend
  /// la requête autorisée.
  Query<Map<String, dynamic>> get _published =>
      _col.where('isDraft', isEqualTo: false);

  // ============================================================
  // LECTURE
  // ============================================================

  /// Lieux publiés d'une catégorie, du plus récent au plus ancien.
  ///
  /// Demande l'index composite (categoryKey, isDraft, updatedAt DESC) — voir
  /// firestore.indexes.json.
  Stream<List<Place>> watchByCategory(String categoryKey, {int? limit}) {
    Query<Map<String, dynamic>> q = _published
        .where('categoryKey', isEqualTo: categoryKey)
        .orderBy('updatedAt', descending: true);
    if (limit != null) q = q.limit(limit);
    return q.snapshots().map(_map);
  }

  /// Tous les lieux publiés, toutes catégories (recherche globale, carte).
  Stream<List<Place>> watchAllPlaces({int? limit}) {
    Query<Map<String, dynamic>> q =
        _published.orderBy('updatedAt', descending: true);
    if (limit != null) q = q.limit(limit);
    return q.snapshots().map(_map);
  }

  /// Lieux mis en avant, filtrés côté serveur.
  Stream<List<Place>> watchFeaturedPlaces({int limit = 20}) {
    return _published
        .where('isFeatured', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map(_map);
  }

  Future<List<Place>> fetchByCategory(String categoryKey, {int? limit}) async {
    Query<Map<String, dynamic>> q = _published
        .where('categoryKey', isEqualTo: categoryKey)
        .orderBy('updatedAt', descending: true);
    if (limit != null) q = q.limit(limit);
    return _map(await q.get());
  }

  Future<Place?> fetchById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Place.fromDoc(doc);
  }

  Stream<Place?> watchById(String id) {
    return _col.doc(id).snapshots().map((d) => d.exists ? Place.fromDoc(d) : null);
  }

  /// Page de lieux d'une catégorie, pour le défilement infini.
  ///
  /// [startAfter] est le dernier document de la page précédente.
  Future<QuerySnapshot<Map<String, dynamic>>> fetchPage({
    String? categoryKey,
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> q = _col;
    if (categoryKey != null) {
      q = q.where('categoryKey', isEqualTo: categoryKey);
    }
    q = q.orderBy('updatedAt', descending: true);
    if (startAfter != null) q = q.startAfterDocument(startAfter);
    return q.limit(limit).get();
  }

  // ============================================================
  // ÉCRITURE
  // ============================================================

  /// Upload des images via [ImageService] (compression JPEG + Storage), puis
  /// retourne les URLs publiques.
  Future<List<String>> uploadImages({
    required String folder,
    required List<File> files,
    void Function(int current, int total)? onProgress,
  }) {
    if (files.isEmpty) return Future.value(const <String>[]);
    return ImageService.uploadMultipleImages(
      imageFiles: files,
      category: folder,
      onProgress: onProgress,
    );
  }

  Future<String> createPlace({
    required Place place,
    List<File> images = const [],
    void Function(int current, int total)? onProgress,
  }) async {
    final urls = await uploadImages(
      folder: collectionName,
      files: images,
      onProgress: onProgress,
    );

    final doc = _col.doc();
    await doc.set({
      ...place.toMap(),
      'photos': [...place.photos, ...urls],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Met à jour un lieu. `createdAt` n'est pas touché.
  Future<void> updatePlace({
    required String id,
    required Place updated,
    List<File> newImages = const [],
    bool replacePhotos = false,
    void Function(int current, int total)? onProgress,
  }) async {
    var photos = updated.photos;
    if (newImages.isNotEmpty) {
      final urls = await uploadImages(
        folder: collectionName,
        files: newImages,
        onProgress: onProgress,
      );
      photos = replacePhotos ? urls : [...updated.photos, ...urls];
    }

    await _col.doc(id).update({
      ...updated.toMap(),
      'photos': photos,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePlace(String id) => _col.doc(id).delete();

  /// Déplace tous les lieux d'une catégorie vers une autre.
  ///
  /// Permet de vider une catégorie avant de la supprimer. Écrit par lots de
  /// 500 (limite d'un batch Firestore).
  Future<int> reassignCategory({
    required String fromKey,
    required String toKey,
  }) async {
    var moved = 0;
    while (true) {
      final snap = await _col
          .where('categoryKey', isEqualTo: fromKey)
          .limit(500)
          .get();
      if (snap.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'categoryKey': toKey,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      moved += snap.docs.length;
    }
    return moved;
  }
}
