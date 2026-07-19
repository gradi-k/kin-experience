import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

import '../models/ad_model.dart';

class AdsService {
  AdsService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('ads');

  Stream<List<AdModel>> watchActiveAds() {
    return _col
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(AdModel.fromDoc).toList());
  }

  Stream<List<AdModel>> watchAllAds() {
    return _col
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(AdModel.fromDoc).toList());
  }

  Future<void> createAd({
    required String title,
    required String subtitle,
    required String ctaLabel,
    required String link,
    required bool isActive,
    required File imageFile,
  }) async {
    final now = DateTime.now();

    final docRef = await _col.add({
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'ctaLabel': ctaLabel.trim(),
      'link': link.trim(),
      'image': '',
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

  /// Upload image : compresse en WebP sur mobile, upload brut sur web
  Future<String> uploadAdImage({
    required String adId,
    required File file,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final baseName = p.basenameWithoutExtension(file.path);

    if (kIsWeb) {
      // Web : upload direct sans compression
      final bytes = await file.readAsBytes();
      final ext = p.extension(file.path).isNotEmpty
          ? p.extension(file.path)
          : '.jpg';
      final filename = '${baseName}_$timestamp$ext';
      final contentType = ext == '.png' ? 'image/png' : 'image/jpeg';

      final ref = _storage.ref().child('ads/$adId/$filename');
      final task = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      return task.ref.getDownloadURL();
    } else {
      // Mobile : compression WebP
      final webpFile = await _convertToWebp(file);
      final filename = '${baseName}_$timestamp.webp';

      final ref = _storage.ref().child('ads/$adId/$filename');
      final task = await ref.putFile(
        webpFile,
        SettableMetadata(contentType: 'image/webp'),
      );
      return task.ref.getDownloadURL();
    }
  }

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
      quality: 80,
    );

    if (result == null) return input;
    return File(result.path);
  }
}