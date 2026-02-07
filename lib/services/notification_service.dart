// lib/services/notification_service.dart
// ✅ VERSION CORRIGÉE - API flutter_local_notifications compatible

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kin_experience/models/app_notification.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // ✅ CORRECTION 1: Icône personnalisée
    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
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
    print('✅ NotificationService initialized');
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
    // ✅ CORRECTION 2: Icône + Couleur (pas const car Color n'est pas const)
    final androidDetails = AndroidNotificationDetails(
      'kin_city_channel',
      'Kin City Guide',
      channelDescription: 'Notifications de Kin City Guide',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@drawable/ic_notification',  // ✅ Icône personnalisée
      color: const Color(0xFF0B7A4A),     // ✅ Ton vert
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // ✅ CORRECTION 3: Syntaxe correcte pour show()
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: message.notification?.title ?? 'Nouvelle notification',
      body: message.notification?.body ?? '',
      notificationDetails: details,
      payload: json.encode(message.data),
    );
  }

  Stream<List<AppNotification>> watchAllNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('🔔 watchAllNotifications: No user logged in');
      return Stream.value([]);
    }

    print('🔔 watchAllNotifications: Starting stream for user ${user.uid}');

    return _firestore
        .collection('notifications')
        .limit(100)
        .snapshots()
        .map((snapshot) {
      print('🔔 watchAllNotifications: Received ${snapshot.docs.length} notifications');

      final notifications = snapshot.docs
          .map((doc) {
        try {
          final notif = AppNotification.fromMap(doc.data(), doc.id);
          print('  📄 Notification: ${notif.title} (isRead: ${notif.isRead})');
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
        return shouldShow;
      })
          .toList();

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

  // ✅ CORRECTION 3: watchUnreadCount avec debug détaillé
  Stream<int> watchUnreadCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('🔔 BADGE: No user logged in, returning 0');
      return Stream.value(0);
    }

    print('🔔 BADGE: Starting watchUnreadCount for user ${user.uid}');

    return _firestore
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      print('\n🔔 ===== BADGE UPDATE =====');
      print('🔔 Total unread in Firebase: ${snapshot.docs.length}');

      final count = snapshot.docs.where((doc) {
        final data = doc.data();
        final targetUserId = data['targetUserId'];
        final isGlobal = data['isGlobal'] ?? false;
        final title = data['title'] ?? 'No title';

        final shouldCount = (isGlobal || targetUserId == null || targetUserId == '') ||
            targetUserId == user.uid;

        if (shouldCount) {
          print('  ✅ COUNTING: "$title" (isGlobal: $isGlobal, targetUserId: $targetUserId)');
        } else {
          print('  ⏭️  SKIP: "$title" (targetUserId: $targetUserId != ${user.uid})');
        }

        return shouldCount;
      }).length;

      print('🔔 BADGE COUNT = $count');
      print('🔔 =========================\n');

      return count;
    }).asBroadcastStream();
  }

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
      'isGlobal': true,
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
      'isGlobal': true,
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

// RIVERPOD PROVIDERS
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

// ✅ CORRECTION 4: Nom du provider avec 's'
final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.watchUnreadCount();
});