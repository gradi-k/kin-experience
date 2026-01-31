// lib/services/places_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kin_experience/models/entreprise.dart';
import 'package:kin_experience/models/event.dart';
import 'package:kin_experience/models/hotel.dart';
import 'package:kin_experience/models/place_enums.dart';
import 'package:kin_experience/models/resto.dart';
import 'package:kin_experience/models/shopping.dart';
import 'package:kin_experience/models/site.dart';

/// Repository central pour récupérer les données depuis Firestore.
/// Gère toutes les collections: sites, restaurants, hotels, events, entreprises, shoppings
class PlacesRepository {
  final FirebaseFirestore _firestore;

  PlacesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ============================================================
  // HELPER: Obtenir le nom de collection
  // ============================================================

  String _getCollectionName(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.site:
        return 'sites';
      case PlaceCategory.resto:
        return 'restaurants';
      case PlaceCategory.hotel:
        return 'hotels';
      case PlaceCategory.event:
        return 'events';
      case PlaceCategory.entreprise:
        return 'business';
      case PlaceCategory.shopping:
        return 'shopping';
    }
  }

  // ============================================================
  // STREAMS (temps réel) - Recommandé pour l'UI dynamique
  // ============================================================

  /// Stream de tous les sites
  Stream<List<Site>> watchSites() {
    return _firestore.collection('sites').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Site.fromMap(doc.data(), doc.id)).toList();
    });
  }

  /// Stream de tous les restaurants
  Stream<List<Resto>> watchRestos() {
    return _firestore.collection('restaurants').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Resto.fromMap(doc.data(), doc.id)).toList();
    });
  }

  /// Stream de tous les hôtels
  Stream<List<Hotel>> watchHotels() {
    return _firestore.collection('hotels').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Hotel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  /// Stream de tous les événements
  Stream<List<Event>> watchEvents() {
    return _firestore.collection('events').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Event.fromMap(doc.data(), doc.id)).toList();
    });
  }

  /// Stream de toutes les entreprises
  Stream<List<Entreprise>> watchEntreprises() {
    return _firestore.collection('business').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Entreprise.fromMap(doc.data(), doc.id)).toList();
    });
  }

  /// Stream de tous les shoppings/marchés
  Stream<List<Shopping>> watchShoppings() {
    return _firestore.collection('shopping').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Shopping.fromMap(doc.data(), doc.id)).toList();
    });
  }

  // ============================================================
  // FEATURED ITEMS (éléments mis en avant)
  // ============================================================

  /// Stream des éléments mis en avant (isFeatured == true)
  Stream<List<dynamic>> watchFeaturedPlaces() {
    return _combineAllStreams().map((allPlaces) {
      return allPlaces.where((place) {
        try {
          return place.isFeatured == true;
        } catch (_) {
          return false;
        }
      }).toList();
    });
  }

  // ============================================================
  // COMBINED STREAM (toutes les collections)
  // ============================================================

  /// Combine tous les streams en un seul
  Stream<List<dynamic>> _combineAllStreams() {
    return watchSites().asyncExpand((sites) {
      return watchRestos().asyncExpand((restos) {
        return watchHotels().asyncExpand((hotels) {
          return watchEvents().asyncExpand((events) {
            return watchEntreprises().asyncExpand((entreprises) {
              return watchShoppings().map((shoppings) {
                return <dynamic>[
                  ...sites,
                  ...restos,
                  ...hotels,
                  ...events,
                  ...entreprises,
                  ...shoppings,
                ];
              });
            });
          });
        });
      });
    });
  }

  /// Stream de tous les éléments combinés (pour la recherche globale)
  Stream<List<dynamic>> watchAllPlaces() => _combineAllStreams();

  // ============================================================
  // FUTURES (chargement unique) - Pour des cas spécifiques
  // ============================================================

  Future<List<Site>> getSites() async {
    final snapshot = await _firestore.collection('sites').get();
    return snapshot.docs.map((doc) => Site.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<Resto>> getRestos() async {
    final snapshot = await _firestore.collection('restaurants').get();
    return snapshot.docs.map((doc) => Resto.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<Hotel>> getHotels() async {
    final snapshot = await _firestore.collection('hotels').get();
    return snapshot.docs.map((doc) => Hotel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<Event>> getEvents() async {
    final snapshot = await _firestore.collection('events').get();
    return snapshot.docs.map((doc) => Event.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<Entreprise>> getEntreprises() async {
    final snapshot = await _firestore.collection('business').get();
    return snapshot.docs.map((doc) => Entreprise.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<Shopping>> getShoppings() async {
    final snapshot = await _firestore.collection('shopping').get();
    return snapshot.docs.map((doc) => Shopping.fromMap(doc.data(), doc.id)).toList();
  }

  // ============================================================
  // GET BY ID
  // ============================================================

  Future<dynamic> getPlaceById(PlaceCategory category, String id) async {
    final collectionName = _getCollectionName(category);
    final doc = await _firestore.collection(collectionName).doc(id).get();

    if (!doc.exists) return null;

    final data = doc.data()!;
    switch (category) {
      case PlaceCategory.site:
        return Site.fromMap(data, doc.id);
      case PlaceCategory.resto:
        return Resto.fromMap(data, doc.id);
      case PlaceCategory.hotel:
        return Hotel.fromMap(data, doc.id);
      case PlaceCategory.event:
        return Event.fromMap(data, doc.id);
      case PlaceCategory.entreprise:
        return Entreprise.fromMap(data, doc.id);
      case PlaceCategory.shopping:
        return Shopping.fromMap(data, doc.id);
    }
  }

  // ============================================================
  // BY CATEGORY
  // ============================================================

  Stream<List<dynamic>> watchByCategory(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.site:
        return watchSites();
      case PlaceCategory.resto:
        return watchRestos();
      case PlaceCategory.hotel:
        return watchHotels();
      case PlaceCategory.event:
        return watchEvents();
      case PlaceCategory.entreprise:
        return watchEntreprises();
      case PlaceCategory.shopping:
        return watchShoppings();
    }
  }
}

// ⚠️ IMPORTANT: Supprimer l'extension PlaceCategoryFirestore si elle existe
// dans place_enums.dart pour éviter les conflits.
// Utiliser uniquement la méthode _getCollectionName() du repository.