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

import 'package:kin_experience/models/app_notification.dart';

/// Service de notifications - Version migrée vers /notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialisation du service
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _onNotificationTapped(response);
      },
    );

    await _requestPermissions();
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }

    await _saveToken();
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
    await _showLocalNotification(message);
  }

  void _handleNotificationOpen(RemoteMessage message) {
    final data = message.data;
    final category = data['category'];
    final itemId = data['itemId'];

    if (kDebugMode) {
      print('Notification opened: category=$category, itemId=$itemId');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        final category = data['category'];
        final itemId = data['itemId'];

        if (kDebugMode) {
          print('Local notification tapped: category=$category, itemId=$itemId');
        }
      } catch (_) {}
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
  // ✅ NOTIFICATIONS - Sans orderBy (tri côté client)
  // ============================================================

  Stream<List<AppNotification>> watchAllNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('🔔 watchAllNotifications: No user logged in');
      return Stream.value([]);
    }

    print('🔔 watchAllNotifications: Starting stream for user ${user.uid}');

    // ✅ CORRIGÉ : Pas d'orderBy pour récupérer TOUTES les notifications
    return _firestore
        .collection('notifications')
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

      // ✅ Trier côté client par date (supporte timestamp ET createdAt)
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    }).asBroadcastStream();
  }

  Stream<List<AppNotification>> watchUserNotifications() {
    return watchAllNotifications();
  }

  Stream<List<AppNotification>> watchGlobalNotifications() {
    return watchAllNotifications();
  }

  Future<void> markAsRead(String notificationId, {bool isGlobal = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});

      print('✅ Notification marked as read: $notificationId');
    } catch (e) {
      if (kDebugMode) {
        print('Error marking notification as read: $e');
      }
    }
  }

  Future<void> markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();

      for (final doc in notifications.docs) {
        final data = doc.data();
        final targetUserId = data['targetUserId'];

        if (targetUserId == null || targetUserId == '' || targetUserId == user.uid) {
          batch.update(doc.reference, {'isRead': true});
        }
      }

      await batch.commit();
      print('✅ All notifications marked as read');
    } catch (e) {
      if (kDebugMode) {
        print('Error marking all as read: $e');
      }
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();

      print('✅ Notification deleted: $notificationId');
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting notification: $e');
      }
    }
  }

  Stream<int> watchUnreadCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final count = snapshot.docs.where((doc) {
        final data = doc.data();
        final targetUserId = data['targetUserId'];
        final isGlobal = data['isGlobal'] ?? false;

        // ✅ Support isGlobal ET targetUserId
        return (isGlobal || targetUserId == null || targetUserId == '') ||
            targetUserId == user.uid;
      }).length;

      print('🔔 Unread count: $count');
      return count;
    }).asBroadcastStream();
  }

  // ============================================================
  // ADMIN : Créer des notifications
  // ============================================================

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
      'targetUserId': null,
    });

    print('🔔 Notification created with ID: ${docRef.id}');
  }

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
      'targetUserId': null,
    });

    print('🔔 Notification created with ID: ${docRef.id}');
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
      case 'business':
      case 'entreprises':
        return 'Business';
      case 'shopping':
      case 'shoppings':
        return 'Market';
      default:
        return category;
    }
  }
}

// ============================================================
// RIVERPOD PROVIDERS
// ============================================================

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final userNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.watchUserNotifications();
});

final globalNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.watchGlobalNotifications();
});

final allNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.watchAllNotifications();
});

final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.watchUnreadCount();
});