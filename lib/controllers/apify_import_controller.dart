// lib/controllers/apify_import_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/apify_import_run.dart';

/// Historique des imports Apify, du plus récent au plus ancien.
final apifyImportsProvider =
    StreamProvider.autoDispose<List<ApifyImportRun>>((ref) {
  return FirebaseFirestore.instance
      .collection('apify_imports')
      .orderBy('startedAt', descending: true)
      .limit(30)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => ApifyImportRun.fromMap(d.data(), d.id)).toList());
});

/// Lance un import Apify via la Cloud Function `startApifyImport`.
///
/// Réservé aux admins côté serveur ; lève [FirebaseFunctionsException] en cas
/// de refus (catégorie invalide, droits insuffisants, échec Apify).
Future<String> startApifyImportCall({
  required String categoryKey,
  String? commune,
  String? customQuery,
  int maxItems = 50,
}) async {
  final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
      .httpsCallable('startApifyImport');
  final res = await callable.call<Map<String, dynamic>>({
    'categoryKey': categoryKey,
    if (commune != null && commune.isNotEmpty) 'commune': commune,
    if (customQuery != null && customQuery.trim().isNotEmpty)
      'customQuery': customQuery.trim(),
    'maxItems': maxItems,
  });
  return (res.data['runId'] ?? '').toString();
}
