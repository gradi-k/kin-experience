import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hotel.dart';
import '../models/resto.dart';
import '../models/site.dart';
import '../models/event.dart';
import '../models/entreprise.dart';
import '../models/shopping.dart';
import '../models/place_enums.dart';

/// Service centralisé pour récupérer les données des lieux depuis Firebase.
/// Fournit des méthodes de streaming (temps réel) et des méthodes one-shot.
class PlacesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // COLLECTIONS NAMES (à adapter selon votre structure Firebase)
  // ═══════════════════════════════════════════════════════════════════════════
  static const String hotelsCollection = 'hotels';
  static const String restosCollection = 'restos';
  static const String sitesCollection = 'sites';
  static const String eventsCollection = 'events';
  static const String entreprisesCollection = 'entreprises';
  static const String shoppingsCollection = 'shoppings';

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAMS (temps réel)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream de tous les hôtels
  Stream<List<Hotel>> watchHotels() {
    return _db.collection(hotelsCollection).snapshots().map((snap) {
      return snap.docs.map((doc) => Hotel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  /// Stream de tous les restaurants
  Stream<List<Resto>> watchRestos() {
    return _db.collection(restosCollection).snapshots().map((snap) {
      return snap.docs.map((doc) => Resto.fromMap(doc.data(), doc.id)).toList();
    });
  }

  /// Stream de tous les sites touristiques
  Stream<List<Site>> watchSites() {
    return _db.collection(sitesCollection).snapshots().map((snap) {
      return snap.docs.map((doc) => Site.fromMap(doc.data(), doc.id)).toList();
    });
  }

  /// Stream de tous les événements
  Stream<List<Event>> watchEvents() {
    return _db.collection(eventsCollection).snapshots().map((snap) {
      return snap.docs.map((doc) => Event.fromMap(doc.data(), doc.id)).toList();
    });
  }

  /// Stream de toutes les entreprises
  Stream<List<Entreprise>> watchEntreprises() {
    return _db.collection(entreprisesCollection).snapshots().map((snap) {
      return snap.docs
          .map((doc) => Entreprise.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Stream de tous les shoppings
  Stream<List<Shopping>> watchShoppings() {
    return _db.collection(shoppingsCollection).snapshots().map((snap) {
      return snap.docs
          .map((doc) => Shopping.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAMS FEATURED (temps réel - éléments mis en avant)
  // ═══════════════════════════════════════════════════════════════════════════

  Stream<List<Hotel>> watchFeaturedHotels() {
    return _db
        .collection(hotelsCollection)
        .where('isFeatured', isEqualTo: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) => Hotel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<Resto>> watchFeaturedRestos() {
    return _db
        .collection(restosCollection)
        .where('isFeatured', isEqualTo: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) => Resto.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<Site>> watchFeaturedSites() {
    return _db
        .collection(sitesCollection)
        .where('isFeatured', isEqualTo: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) => Site.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<Event>> watchFeaturedEvents() {
    return _db
        .collection(eventsCollection)
        .where('isFeatured', isEqualTo: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) => Event.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<Entreprise>> watchFeaturedEntreprises() {
    return _db
        .collection(entreprisesCollection)
        .where('isFeatured', isEqualTo: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => Entreprise.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<Shopping>> watchFeaturedShoppings() {
    return _db
        .collection(shoppingsCollection)
        .where('isFeatured', isEqualTo: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => Shopping.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ONE-SHOT FETCHES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Hotel>> fetchHotels() async {
    final snap = await _db.collection(hotelsCollection).get();
    return snap.docs.map((doc) => Hotel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<Resto>> fetchRestos() async {
    final snap = await _db.collection(restosCollection).get();
    return snap.docs.map((doc) => Resto.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<Site>> fetchSites() async {
    final snap = await _db.collection(sitesCollection).get();
    return snap.docs.map((doc) => Site.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<Event>> fetchEvents() async {
    final snap = await _db.collection(eventsCollection).get();
    return snap.docs.map((doc) => Event.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<Entreprise>> fetchEntreprises() async {
    final snap = await _db.collection(entreprisesCollection).get();
    return snap.docs
        .map((doc) => Entreprise.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<Shopping>> fetchShoppings() async {
    final snap = await _db.collection(shoppingsCollection).get();
    return snap.docs
        .map((doc) => Shopping.fromMap(doc.data(), doc.id))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FETCH BY ID
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Hotel?> fetchHotelById(String id) async {
    final doc = await _db.collection(hotelsCollection).doc(id).get();
    if (!doc.exists) return null;
    return Hotel.fromMap(doc.data()!, doc.id);
  }

  Future<Resto?> fetchRestoById(String id) async {
    final doc = await _db.collection(restosCollection).doc(id).get();
    if (!doc.exists) return null;
    return Resto.fromMap(doc.data()!, doc.id);
  }

  Future<Site?> fetchSiteById(String id) async {
    final doc = await _db.collection(sitesCollection).doc(id).get();
    if (!doc.exists) return null;
    return Site.fromMap(doc.data()!, doc.id);
  }

  Future<Event?> fetchEventById(String id) async {
    final doc = await _db.collection(eventsCollection).doc(id).get();
    if (!doc.exists) return null;
    return Event.fromMap(doc.data()!, doc.id);
  }

  Future<Entreprise?> fetchEntrepriseById(String id) async {
    final doc = await _db.collection(entreprisesCollection).doc(id).get();
    if (!doc.exists) return null;
    return Entreprise.fromMap(doc.data()!, doc.id);
  }

  Future<Shopping?> fetchShoppingById(String id) async {
    final doc = await _db.collection(shoppingsCollection).doc(id).get();
    if (!doc.exists) return null;
    return Shopping.fromMap(doc.data()!, doc.id);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FETCH BY CATEGORY
  // ═══════════════════════════════════════════════════════════════════════════

  Future<dynamic> fetchPlaceById(PlaceCategory category, String id) async {
    switch (category) {
      case PlaceCategory.hotel:
        return await fetchHotelById(id);
      case PlaceCategory.resto:
        return await fetchRestoById(id);
      case PlaceCategory.site:
        return await fetchSiteById(id);
      case PlaceCategory.event:
        return await fetchEventById(id);
      case PlaceCategory.entreprise:
        return await fetchEntrepriseById(id);
      case PlaceCategory.shopping:
        return await fetchShoppingById(id);
    }
  }

  /// Récupère le nom de la collection Firebase pour une catégorie donnée
  String getCollectionName(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.hotel:
        return hotelsCollection;
      case PlaceCategory.resto:
        return restosCollection;
      case PlaceCategory.site:
        return sitesCollection;
      case PlaceCategory.event:
        return eventsCollection;
      case PlaceCategory.entreprise:
        return entreprisesCollection;
      case PlaceCategory.shopping:
        return shoppingsCollection;
    }
  }
}