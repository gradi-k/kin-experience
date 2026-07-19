// lib/controllers/connectivity_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Détecte le mode hors-ligne via les métadonnées Firestore :
/// si les snapshots proviennent du cache, le serveur est injoignable.
/// (Sonde légère : 1 document, pas de dépendance connectivity_plus.)
final isOfflineProvider = StreamProvider<bool>((ref) {
  return FirebaseFirestore.instance
      .collection('sites')
      .limit(1)
      .snapshots(includeMetadataChanges: true)
      .map((snap) => snap.metadata.isFromCache)
      .distinct();
});
