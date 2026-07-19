import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/place.dart';
import 'auth_controller.dart';

/// Favoris de l'utilisateur, stockés dans `users/{uid}/favorites/{placeId}`.
///
/// Chaque document est un instantané du lieu (et non une simple référence) :
/// la liste s'affiche sans relire `places`, et un favori survit à la
/// suppression du lieu d'origine.
///
/// L'id du document est l'id du lieu. La collection unique `places` garantit
/// son unicité — l'ancien schéma préfixait par la collection
/// (`hotels_abc123`) pour éviter les collisions entre les 6 collections.
class FavoritesController extends StateNotifier<AsyncValue<List<Place>>> {
  final String? _uid;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  FavoritesController(this._uid) : super(const AsyncLoading()) {
    _init();
  }

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites');
  }

  void _init() {
    final col = _col;
    if (col == null) {
      // Visiteur : pas de favoris, mais pas d'erreur non plus.
      state = const AsyncValue.data([]);
      return;
    }

    _subscription = col.snapshots().listen(
      (snapshot) {
        state = AsyncValue.data(
          snapshot.docs.map((d) => Place.fromMap(d.data(), d.id)).toList(),
        );
      },
      onError: (Object e, StackTrace st) {
        state = AsyncValue.error(e, st);
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Ajoute ou retire un favori. Sans effet pour un visiteur : l'appelant
  /// doit passer par `requireAuth` (views/auth/auth_guard.dart) d'abord.
  Future<void> toggleFavorite(Place place) async {
    final col = _col;
    if (col == null) {
      debugPrint('⚠️ toggleFavorite ignoré : aucun utilisateur connecté');
      return;
    }

    final doc = col.doc(place.id);
    if ((await doc.get()).exists) {
      await doc.delete();
    } else {
      await doc.set({
        ...place.toMap(),
        'favoritedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  bool isFavorite(Place place) {
    final current = state;
    if (current is AsyncData<List<Place>>) {
      return current.value.any((e) => e.id == place.id);
    }
    return false;
  }
}

/// Favoris de l'utilisateur courant.
///
/// Dépend de [currentUserProvider] : le controller est recréé à chaque
/// connexion ou déconnexion. L'ancienne version lisait `currentUser` une seule
/// fois à la construction, si bien que les favoris restaient vides après une
/// connexion jusqu'au redémarrage de l'app.
final favoritesControllerProvider =
    StateNotifierProvider<FavoritesController, AsyncValue<List<Place>>>((ref) {
  final user = ref.watch(currentUserProvider);
  return FavoritesController(user?.uid);
});
