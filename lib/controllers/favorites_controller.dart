import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';


import '../models/place_enums.dart';
import '../models/site.dart';
import '../models/resto.dart';
import '../models/hotel.dart';
import '../models/event.dart';
import '../models/entreprise.dart';
import '../models/shopping.dart';

class FavoritesController extends StateNotifier<AsyncValue<List<dynamic>>> {
  FavoritesController() : super(const AsyncLoading()) {
    _init();
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  String _favDocId(dynamic place, PlaceCategory category) {
    final baseId = place.id.toString();
    // même logique que toggleFavorite pour éviter les doublons/incohérences
    return baseId.startsWith(category.collectionName)
        ? baseId
        : '${category.collectionName}_$baseId';
  }

  Future<void> _init() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      state = const AsyncValue.data([]);
      return;
    }

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites');

    _subscription = collection.snapshots().listen((snapshot) {
      try {
        final results = snapshot.docs.map((doc) {
          final data = doc.data();
          final category = (data['category'] as String? ?? '').trim();

          switch (category) {
            case 'sites':
              return Site.fromMap(data, doc.id);
            case 'restos':
              return Resto.fromMap(data, doc.id);
            case 'hotels':
              return Hotel.fromMap(data, doc.id);
            case 'events':
              return Event.fromMap(data, doc.id);
            case 'entreprises':
              return Entreprise.fromMap(data, doc.id);
            case 'shopping':
              return Shopping.fromMap(data, doc.id);
            default:
              return null;
          }
        }).whereType<dynamic>().toList();

        state = AsyncValue.data(results);
      } catch (e, st) {
        state = AsyncValue.error(e, st);
      }
    }, onError: (e, st) {
      state = AsyncValue.error(e, st);
    });
  }

  Future<void> toggleFavorite(dynamic place, PlaceCategory category) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = _favDocId(place, category);

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(docId);

    final snap = await docRef.get();
    if (snap.exists) {
      await docRef.delete();
    } else {
      final map = place.toMap();
      map['category'] = category.collectionName;
      await docRef.set(map);
    }
  }

  bool isFavorite(dynamic place, PlaceCategory category) {
    final docId = _favDocId(place, category);
    final currentState = state;

    if (currentState is AsyncData<List<dynamic>>) {
      return currentState.value.any((e) => e.id == docId);
    }
    return false;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider
final favoritesControllerProvider =
StateNotifierProvider<FavoritesController, AsyncValue<List<dynamic>>>((ref) {
  return FavoritesController();
});
