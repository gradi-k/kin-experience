// lib/services/new_place_watcher_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

/// Service qui écoute les ajouts de nouveaux lieux dans Firebase
/// et crée automatiquement des notifications.
///
/// Ce service peut être initialisé une seule fois au démarrage de l'app
/// (par exemple dans main.dart après l'initialisation de Firebase).
///
/// Note: Pour les notifications push, il est recommandé d'utiliser
/// Firebase Cloud Functions côté serveur pour une meilleure fiabilité.
class NewPlaceWatcherService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Subscriptions pour pouvoir les annuler
  final List<StreamSubscription> _subscriptions = [];

  // Collections à surveiller
  static const List<String> _collections = [
    'hotels',
    'restaurants',     // ✅ CORRIGÉ
    'sites',
    'events',
    'business',        // ✅ CORRIGÉ (si tu utilises 'business')
    'shopping',        // ✅ CORRIGÉ
  ];

  // Timestamps de dernière vérification pour éviter les doublons
  final Map<String, DateTime> _lastChecked = {};

  /// Démarre la surveillance de toutes les collections
  void startWatching() {
    // Initialiser les timestamps
    final now = DateTime.now();
    for (final collection in _collections) {
      _lastChecked[collection] = now;
    }

    // Écouter chaque collection
    for (final collection in _collections) {
      final subscription = _watchCollection(collection);
      _subscriptions.add(subscription);
    }

    print('NewPlaceWatcherService: Started watching ${_collections.length} collections');
  }

  /// Arrête la surveillance
  void stopWatching() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    print('NewPlaceWatcherService: Stopped watching');
  }

  StreamSubscription _watchCollection(String collection) {
    return _db
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .limit(5) // On surveille les 5 derniers pour ne pas surcharger
        .snapshots()
        .listen((snapshot) {
      _handleSnapshot(collection, snapshot);
    }, onError: (error) {
      print('NewPlaceWatcherService: Error watching $collection: $error');
    });
  }

  void _handleSnapshot(String collection, QuerySnapshot<Map<String, dynamic>> snapshot) {
    final lastCheck = _lastChecked[collection] ?? DateTime.now();

    for (final change in snapshot.docChanges) {
      // On ne s'intéresse qu'aux ajouts
      if (change.type != DocumentChangeType.added) continue;

      final doc = change.doc;
      final data = doc.data();
      if (data == null) continue;

      // Vérifier si c'est vraiment un nouvel élément (après notre dernier check)
      final createdAt = _parseTimestamp(data['createdAt']);
      if (createdAt == null || createdAt.isBefore(lastCheck)) continue;

      // Créer la notification
      _createNotificationForNewPlace(
        collection: collection,
        docId: doc.id,
        data: data,
      );
    }

    // Mettre à jour le timestamp de dernière vérification
    _lastChecked[collection] = DateTime.now();
  }

  Future<void> _createNotificationForNewPlace({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final nom = (data['nom'] ?? '').toString();
    if (nom.isEmpty) return;

    final photos = data['photos'] as List?;
    final imageUrl = photos != null && photos.isNotEmpty
        ? photos.first.toString()
        : null;

    try {
      if (collection == 'events') {
        await _notificationService.createNewEventNotification(
          eventId: docId,
          eventName: nom,
          imageUrl: imageUrl,
        );
      } else {
        await _notificationService.createNewPlaceNotification(
          placeId: docId,
          placeName: nom,
          category: collection,
          imageUrl: imageUrl,
        );
      }
      print('NewPlaceWatcherService: Created notification for $nom in $collection');
    } catch (e) {
      print('NewPlaceWatcherService: Error creating notification: $e');
    }
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Extension pour faciliter l'initialisation
extension NewPlaceWatcherExtension on NewPlaceWatcherService {
  /// Initialise le watcher seulement si l'utilisateur est connecté
  static NewPlaceWatcherService? initIfAuthenticated() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final watcher = NewPlaceWatcherService();
    watcher.startWatching();
    return watcher;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EXEMPLE D'UTILISATION DANS MAIN.DART
// ═══════════════════════════════════════════════════════════════════════════
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//
//   // Initialiser le watcher de nouveaux lieux
//   NewPlaceWatcherService? placeWatcher;
//
//   // Écouter les changements d'état d'auth
//   FirebaseAuth.instance.authStateChanges().listen((user) {
//     if (user != null) {
//       placeWatcher ??= NewPlaceWatcherService()..startWatching();
//     } else {
//       placeWatcher?.stopWatching();
//       placeWatcher = null;
//     }
//   });
//
//   runApp(const ProviderScope(child: MyApp()));
// }