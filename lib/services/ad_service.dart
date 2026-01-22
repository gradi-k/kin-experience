import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

import '../models/ad_model.dart';

/// Firebase-backed service for Ads.
/// Collection: ads
/// Storage: ads/<adId>/<filename>.webp
class AdsService {
  AdsService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('ads');

  /// Stream for active ads only (used by the carousel).
  Stream<List<AdModel>> watchActiveAds() {
    return _col
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(AdModel.fromDoc).toList());
  }

  /// Stream for all ads (used by admin list).
  Stream<List<AdModel>> watchAllAds() {
    return _col
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(AdModel.fromDoc).toList());
  }

  /// Creates an ad and uploads its image (converted to WEBP).
  Future<void> createAd({
    required String title,
    required String subtitle,
    required String ctaLabel,
    required String link,
    required bool isActive,
    required File imageFile,
  }) async {
    final now = DateTime.now();

    // Create doc first to get an ID
    final docRef = await _col.add({
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'ctaLabel': ctaLabel.trim(),
      'link': link.trim(),
      'image': '', // will be filled after upload
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    final imageUrl = await uploadAdImage(adId: docRef.id, file: imageFile);

    await docRef.update({
      'image': imageUrl,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Updates an ad. If [newImageFile] is provided, it will be converted to WEBP and uploaded.
  Future<void> updateAd({
    required String adId,
    required String title,
    required String subtitle,
    required String ctaLabel,
    required String link,
    required bool isActive,
    File? newImageFile,
  }) async {
    final docRef = _col.doc(adId);

    String? imageUrl;
    if (newImageFile != null) {
      imageUrl = await uploadAdImage(adId: adId, file: newImageFile);
    }

    final patch = <String, dynamic>{
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'ctaLabel': ctaLabel.trim(),
      'link': link.trim(),
      'isActive': isActive,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (imageUrl != null) patch['image'] = imageUrl;

    await docRef.update(patch);
  }

  Future<void> deleteAd(String adId) async {
    // best-effort remove storage folder
    try {
      final folderRef = _storage.ref().child('ads/$adId');
      final list = await folderRef.listAll();
      for (final item in list.items) {
        await item.delete();
      }
    } catch (_) {}
    await _col.doc(adId).delete();
  }

  Future<void> toggleAd({required String adId, required bool isActive}) async {
    await _col.doc(adId).update({
      'isActive': isActive,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Uploads an image after converting it to WEBP.
  /// Returns the Firebase Storage download URL.
  Future<String> uploadAdImage({
    required String adId,
    required File file,
  }) async {
    final webpFile = await _convertToWebp(file);
    final baseName = p.basenameWithoutExtension(file.path);
    final filename = '${baseName}_${DateTime.now().millisecondsSinceEpoch}.webp';

    final ref = _storage.ref().child('ads/$adId/$filename');

    final task = await ref.putFile(
      webpFile,
      SettableMetadata(contentType: 'image/webp'),
    );

    return task.ref.getDownloadURL();
  }

  /// Converts to WEBP with reasonable compression to reduce payload.
  /// Uses flutter_image_compress (Android/iOS).
  Future<File> _convertToWebp(File input) async {
    final dir = Directory.systemTemp;
    final outPath = p.join(
      dir.path,
      'ad_${DateTime.now().millisecondsSinceEpoch}.webp',
    );

    final result = await FlutterImageCompress.compressAndGetFile(
      input.absolute.path,
      outPath,
      format: CompressFormat.webp,
      quality: 80, // adjust if you want smaller files (60-80 is typical)
    );

    if (result == null) {
      // fallback: upload original file if conversion fails
      return input;
    }
    return File(result.path);
  }
}
