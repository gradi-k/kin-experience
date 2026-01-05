import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/site.dart';
import '../models/resto.dart';
import '../models/hotel.dart';
import '../models/event.dart';
import '../models/entreprise.dart';
import 'places_controller.dart';

/// Contrôleur chargé de gérer la liste des favoris d’un utilisateur.
/// Il écoute en temps réel la collection `users/{uid}/favorites` et
/// expose un état [AsyncValue<List<dynamic>>] afin d’afficher la liste
/// dans l’interface.  Il fournit également une méthode pour ajouter ou
/// retirer un lieu des favoris.
class FavoritesController extends StateNotifier<AsyncValue<List<dynamic>>> {
  FavoritesController(this.ref) : super(const AsyncLoading()) {
    _init();
  }

  final Ref ref;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  Future<void> _init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Pas d’utilisateur connecté : favoris vide
      state = const AsyncValue.data([]);
      return;
    }
    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites');
    // Écoute en temps réel les modifications de la collection
    _subscription = collection.snapshots().listen((snapshot) {
      try {
        final results = snapshot.docs.map((doc) {
          final data = doc.data();
          final category = data['category'] as String? ?? '';
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

  /// Ajoute ou supprime un lieu des favoris.  Si le document existe
  /// déjà, il est supprimé ; sinon il est créé avec les données du
  /// lieu et la catégorie.  Le document est identifié par
  /// `collectionName_id` afin d’éviter les collisions entre
  /// catégories.
  Future<void> toggleFavorite(dynamic place, PlaceCategory category) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Si l’identifiant du lieu commence déjà par la catégorie, on
    // l’utilise tel quel (cas des favoris existants).  Sinon on
    // préfixe avec la collection pour éviter les collisions entre
    // catégories.
    final baseId = place.id.toString();
    final docId = baseId.startsWith(category.collectionName)
        ? baseId
        : '${category.collectionName}_$baseId';
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(docId);
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      await docRef.delete();
    } else {
      final map = place.toMap();
      map['category'] = category.collectionName;
      await docRef.set(map);
    }
  }

  /// Indique si un lieu est déjà présent dans les favoris.
  bool isFavorite(dynamic place, PlaceCategory category) {
    final docId = '${category.collectionName}_${place.id}';
    final currentState = state;
    if (currentState is AsyncData<List<dynamic>>) {
      return currentState.value.any((element) => element.id == docId);
    }
    return false;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider global exposant le [FavoritesController].  Permet d’accéder
/// aux favoris et de déclencher des actions.
final favoritesControllerProvider =
    StateNotifierProvider<FavoritesController, AsyncValue<List<dynamic>>>(
        (ref) => FavoritesController(ref));