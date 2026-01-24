import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/place_enums.dart';
import '../repositories/places_repository.dart';

/// Service "métier" pour les contenus + brouillons.
/// Il harmonise les signatures utilisées dans:
/// - add_content_form.dart
/// - edit_content_from.dart
/// - edit_draft_form.dart
/// - drafts_screen.dart
class ContentService {
  final FirebaseFirestore _db;
  final PlacesRepository _placesRepo;

  ContentService({
    FirebaseFirestore? db,
    PlacesRepository? placesRepository,
  })  : _db = db ?? FirebaseFirestore.instance,
        _placesRepo = placesRepository ?? PlacesRepository();

  CollectionReference<Map<String, dynamic>> get _draftsCol => _db.collection('drafts');

  /// Liste temps réel des contenus d'une catégorie (écran liste).
  Stream<List<PlaceItem>> watchByCategory(PlaceCategory category) {
    return _placesRepo.watchByCategory(category);
  }

  Future<void> deletePlace({
    required PlaceCategory category,
    required String placeId,
  }) {
    return _placesRepo.deletePlace(category: category, id: placeId);
  }

  /// --- Brouillons (drafts) ---

  /// Crée un brouillon.
  /// - [place] : lieu (champs UI)
  /// - [images] : nouvelles images locales à uploader
  Future<String> createDraft({
    required PlaceItem place,
    required List<File> images,
  }) async {
    // On stocke le brouillon avec des photos mixtes:
    // - place.photos : URLs déjà existantes
    // - upload des nouvelles images -> urls ajoutées
    final folder = 'drafts';
    final uploaded = await _placesRepo.uploadImages(folder: folder, files: images);

    final doc = _draftsCol.doc();
    await doc.set({
      ...place.toMap(),
      'photos': [...place.photos, ...uploaded],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateDraft({
    required String draftId,
    required PlaceItem updated,
    required List<File> newImages,
    bool replacePhotos = false,
  }) async {
    final doc = _draftsCol.doc(draftId);

    // Upload éventuel de nouvelles images.
    List<String> photos = updated.photos;
    if (newImages.isNotEmpty) {
      final uploaded = await _placesRepo.uploadImages(folder: 'drafts', files: newImages);
      photos = replacePhotos ? uploaded : [...updated.photos, ...uploaded];
    }

    await doc.update({
      ...updated.toMap(),
      'photos': photos,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream des brouillons (utilisé dans drafts_screen.dart).
  Stream<List<PlaceItem>> watchDrafts() {
    return _draftsCol.orderBy('updatedAt', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) => PlaceItem.fromDoc(d)).toList();
    });
  }

  Future<void> deleteDraft({required String draftId}) async {
    await _draftsCol.doc(draftId).delete();
  }

  /// Publie un brouillon:
  /// 1) lit le draft
  /// 2) l'écrit dans la collection de sa catégorie (place.category)
  /// 3) supprime le draft
  Future<void> publishDraft({required String draftId}) async {
    final snap = await _draftsCol.doc(draftId).get();
    if (!snap.exists) return;

    final draft = PlaceItem.fromDoc(snap);

    // category dans le doc = String (key)
    final cat = PlaceCategoryX.fromKey(draft.category);

    // On réutilise les photos déjà uploadées (URLs).
    final newPlace = draft.copyWith(
      id: '',
      // pas nécessaire mais on s'assure que category est bien la clé stable
      category: cat.key,
    );

    await _db.collection(cat.collectionName).add({
      ...newPlace.toMap(),
      'photos': draft.photos,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await deleteDraft(draftId: draftId);
  }
}
