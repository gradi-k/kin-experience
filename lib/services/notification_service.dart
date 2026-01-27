// lib/services/notification_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// ⚠️ IMPORTANT: Importer le modèle depuis models, NE PAS redéfinir ici
import 'package:kin_experience/models/app_notification.dart';

/// Service de notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // StreamControllers pour éviter "Stream has already been listened to"
  StreamSubscription<QuerySnapshot>? _userNotifSubscription;
  StreamSubscription<QuerySnapshot>? _globalNotifSubscription;

  final _userNotificationsController =
  StreamController<List<AppNotification>>.broadcast();
  final _globalNotificationsController =
  StreamController<List<AppNotification>>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();

  /// Initialisation du service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Configuration des notifications locales
    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );


    // Demander les permissions
    await _requestPermissions();

    // Configurer le handler de messages en foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Configurer le handler quand on tape sur une notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Vérifier si l'app a été ouverte via une notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }

    // Sauvegarder le token FCM
    await _saveToken();

    // Écouter les changements de token
    _messaging.onTokenRefresh.listen(_onTokenRefresh);

    _isInitialized = true;
  }

  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('Notification permission: ${settings.authorizationStatus}');
    }
  }

  Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Sauvegarder aussi dans une collection de tokens pour les notifications de masse
      await _firestore.collection('fcmTokens').doc(token).set({
        'token': token,
        'userId': user?.uid,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving FCM token: $e');
      }
    }
  }

  void _onTokenRefresh(String token) async {
    await _saveToken();
  }

  void _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('Foreground message received: ${message.notification?.title}');
    }

    // Sauvegarder la notification dans Firestore
    await _saveNotificationToFirestore(message);

    // Afficher une notification locale
    await _showLocalNotification(message);
  }

  void _handleNotificationOpen(RemoteMessage message) {
    final data = message.data;
    final category = data['category'];
    final itemId = data['itemId'];

    if (kDebugMode) {
      print('Notification opened: category=$category, itemId=$itemId');
    }

    // La navigation sera gérée par le callback défini dans main.dart
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Gérer le tap sur une notification locale
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        final category = data['category'];
        final itemId = data['itemId'];

        if (kDebugMode) {
          print(
              'Local notification tapped: category=$category, itemId=$itemId');
        }
      } catch (_) {}
    }
  }

  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add({
        'title': message.notification?.title ?? '',
        'description': message.notification?.body ?? '',
        'imageUrl': message.notification?.android?.imageUrl ??
            message.notification?.apple?.imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'category': message.data['category'],
        'placeId': message.data['itemId'],
        'placeName': message.data['placeName'],
        'type': message.data['type'] ?? 'system',
        'isRead': false,
        'targetUserId': user.uid,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error saving notification: $e');
      }
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'kin_city_channel',
      'Kin City Guide',
      channelDescription: 'Notifications de Kin City Guide',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: message.notification?.title ?? 'Nouvelle notification',
      body: message.notification?.body ?? '',
      notificationDetails: details,
      payload: json.encode(message.data),
    );

  }

  // ============================================================
  // FIRESTORE NOTIFICATIONS (historique)
  // ============================================================

  /// Stream des notifications de l'utilisateur courant
  Stream<List<AppNotification>> watchUserNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
          .toList();
    }).asBroadcastStream(); // ✅ Permet plusieurs écoutes
  }

  /// Stream des notifications globales (pour tous les utilisateurs)
  Stream<List<AppNotification>> watchGlobalNotifications() {
    final user = FirebaseAuth.instance.currentUser;

    return _firestore
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
          .where((notif) =>
      // ✅ CORRIGÉ: Accepte null ET chaînes vides comme notifications globales
      notif.targetUserId == null || notif.targetUserId == '' || notif.targetUserId == user?.uid)
          .toList();
    }).asBroadcastStream(); // ✅ Permet plusieurs écoutes
  }

  /// Stream combiné des notifications (user + global)
  Stream<List<AppNotification>> watchAllNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('🔔 watchAllNotifications: No user logged in');
      return Stream.value([]);
    }

    print('🔔 watchAllNotifications: Starting stream for user ${user.uid}');

    // Utiliser Rx.combineLatest2 ou une approche manuelle
    return _firestore
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      print('🔔 watchAllNotifications: Received ${snapshot.docs.length} notifications from Firestore');

      final notifications = snapshot.docs
          .map((doc) {
        try {
          final notif = AppNotification.fromMap(doc.data(), doc.id);
          print('  📄 Notification: ${notif.title} (targetUserId: ${notif.targetUserId})');
          return notif;
        } catch (e) {
          print('  ⚠️ Error parsing notification ${doc.id}: $e');
          return null;
        }
      })
          .whereType<AppNotification>()
          .where((notif) {
        // ✅ CORRIGÉ: Accepte null ET chaînes vides comme notifications globales
        final shouldShow = notif.targetUserId == null ||
            notif.targetUserId == '' ||
            notif.targetUserId == user.uid;
        if (!shouldShow) {
          print('  ⏭️ Skipping notification (targetUserId mismatch): ${notif.title}');
        }
        return shouldShow;
      })
          .toList();

      print('🔔 watchAllNotifications: Returning ${notifications.length} filtered notifications');

      // Trier par date
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    }).asBroadcastStream();
  }

  /// Marquer une notification comme lue
  Future<void> markAsRead(String notificationId, {bool isGlobal = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (isGlobal) {
        // Pour les notifications globales, on les marque dans une sous-collection de l'utilisateur
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('readNotifications')
            .doc(notificationId)
            .set({
          'readAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Pour les notifications utilisateur
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .doc(notificationId)
            .update({'isRead': true});
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error marking notification as read: $e');
      }
    }
  }

  /// Marquer toutes les notifications comme lues
  Future<void> markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();

    // Notifications utilisateur
    final userNotifications = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in userNotifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    // Notifications globales - marquer dans readNotifications
    final globalNotifications = await _firestore
        .collection('notifications')
        .get();

    for (final doc in globalNotifications.docs) {
      batch.set(
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('readNotifications')
            .doc(doc.id),
        {'readAt': FieldValue.serverTimestamp()},
      );
    }

    await batch.commit();
  }

  /// Supprimer une notification
  Future<void> deleteNotification(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  /// Nombre de notifications non lues
  Stream<int> watchUnreadCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .asBroadcastStream();
  }

  // ============================================================
  // ADMIN: Créer des notifications
  // ============================================================

  /// Créer une notification pour un nouvel événement
  Future<void> createNewEventNotification({
    required String eventName,
    required String eventId,
    String? imageUrl,
  }) async {
    print('🔔 Creating notification for new event: $eventName');

    final docRef = await _firestore.collection('notifications').add({
      'title': 'Nouvel événement !',
      'description': '$eventName vient d\'être ajouté',
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'type': NotificationType.newEvent.name,
      'category': 'events',
      'placeId': eventId,
      'placeName': eventName,
      'isRead': false,
      'targetUserId': null, // Notification globale
    });

    print('🔔 Notification created with ID: ${docRef.id}');
  }

  /// Créer une notification pour un nouveau lieu
  Future<void> createNewPlaceNotification({
    required String placeName,
    required String placeId,
    required String category,
    String? imageUrl,
  }) async {
    print('🔔 Creating notification for new place: $placeName (category: $category)');

    final docRef = await _firestore.collection('notifications').add({
      'title': 'Nouveau lieu ajouté !',
      'description': '$placeName vient d\'être ajouté dans ${_getCategoryLabel(category)}',
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'type': NotificationType.newPlace.name,
      'category': category,
      'placeId': placeId,
      'placeName': placeName,
      'isRead': false,
      'targetUserId': null, // Notification globale
    });

    print('🔔 Notification created with ID: ${docRef.id}');
  }

  /// Créer une notification globale quand un admin ajoute un élément
  static Future<void> sendNewItemNotification({
    required String itemName,
    required String category,
    required String itemId,
    String? imageUrl,
  }) async {
    final firestore = FirebaseFirestore.instance;

    await firestore.collection('notifications').add({
      'title': 'Nouveau lieu ajouté !',
      'description':
      '$itemName vient d\'être ajouté dans la catégorie ${_getCategoryLabel(category)}',
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'type': NotificationType.newPlace.name,
      'category': category,
      'placeId': itemId,
      'placeName': itemName,
      'isRead': false,
      'targetUserId': null,
    });
  }

  static String _getCategoryLabel(String category) {
    switch (category) {
      case 'sites':
        return 'Sites touristiques';
      case 'restos':
      case 'restaurants':
        return 'Restaurants';
      case 'hotels':
        return 'Hôtels';
      case 'events':
        return 'Événements';
      case 'entreprises':
        return 'Entreprises';
      case 'shoppings':
      case 'shopping':
        return 'Shopping';
      default:
        return category;
    }
  }

  /// Libérer les ressources
  void dispose() {
    _userNotifSubscription?.cancel();
    _globalNotifSubscription?.cancel();
    _userNotificationsController.close();
    _globalNotificationsController.close();
    _unreadCountController.close();
  }
}

// ============================================================
// RIVERPOD PROVIDERS
// ============================================================

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(() => service.dispose());
  return service;
});

final userNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.watchUserNotifications();
});

final globalNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.watchGlobalNotifications();
});

final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.watchUnreadCount();
});

/// Provider combiné pour toutes les notifications (user + global)
final allNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.watchAllNotifications();
});

/// Provider pour accéder aux notifications avec gestion d'état
final notificationsStateProvider =
StateNotifierProvider<NotificationsNotifier, AsyncValue<List<AppNotification>>>(
        (ref) {
      return NotificationsNotifier(ref);
    });

class NotificationsNotifier extends StateNotifier<AsyncValue<List<AppNotification>>> {
  final Ref _ref;
  StreamSubscription<List<AppNotification>>? _subscription;

  NotificationsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    final service = _ref.read(notificationServiceProvider);
    _subscription = service.watchAllNotifications().listen(
          (notifications) {
        state = AsyncValue.data(notifications);
      },
      onError: (error, stack) {
        state = AsyncValue.error(error, stack);
      },
    );
  }

  Future<void> markAsRead(String id, {bool isGlobal = false}) async {
    final service = _ref.read(notificationServiceProvider);
    await service.markAsRead(id, isGlobal: isGlobal);
  }

  Future<void> markAllAsRead() async {
    final service = _ref.read(notificationServiceProvider);
    await service.markAllAsRead();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}