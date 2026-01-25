// // lib/services/notification_service.dart
// import 'dart:convert';
// import 'dart:io';
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
//
// /// Modèle pour une notification
// class AppNotification {
//   final String id;
//   final String title;
//   final String body;
//   final String? imageUrl;
//   final DateTime timestamp;
//   final String? category;     // site, resto, hotel, event, entreprise, shopping
//   final String? itemId;       // ID de l'élément concerné
//   final bool isRead;
//
//   const AppNotification({
//     required this.id,
//     required this.title,
//     required this.body,
//     this.imageUrl,
//     required this.timestamp,
//     this.category,
//     this.itemId,
//     this.isRead = false,
//   });
//
//   factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
//     return AppNotification(
//       id: id,
//       title: (map['title'] ?? '') as String,
//       body: (map['body'] ?? '') as String,
//       imageUrl: map['imageUrl'] as String?,
//       timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
//       category: map['category'] as String?,
//       itemId: map['itemId'] as String?,
//       isRead: (map['isRead'] ?? false) as bool,
//     );
//   }
//
//   Map<String, dynamic> toMap() {
//     return {
//       'title': title,
//       'body': body,
//       'imageUrl': imageUrl,
//       'timestamp': Timestamp.fromDate(timestamp),
//       'category': category,
//       'itemId': itemId,
//       'isRead': isRead,
//     };
//   }
//
//   AppNotification copyWith({bool? isRead}) {
//     return AppNotification(
//       id: id,
//       title: title,
//       body: body,
//       imageUrl: imageUrl,
//       timestamp: timestamp,
//       category: category,
//       itemId: itemId,
//       isRead: isRead ?? this.isRead,
//     );
//   }
// }
//
// /// Service de notifications
// class NotificationService {
//   static final NotificationService _instance = NotificationService._internal();
//   factory NotificationService() => _instance;
//   NotificationService._internal();
//
//   final FirebaseMessaging _messaging = FirebaseMessaging.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
//
//   bool _isInitialized = false;
//
//   /// Initialisation du service
//   Future<void> initialize() async {
//     if (_isInitialized) return;
//
//     // Configuration des notifications locales
//     const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
//     const iosSettings = DarwinInitializationSettings(
//       requestAlertPermission: true,
//       requestBadgePermission: true,
//       requestSoundPermission: true,
//     );
//
//     const initSettings = InitializationSettings(
//       android: androidSettings,
//       iOS: iosSettings,
//     );
//
//     await _localNotifications.initialize(
//       initSettings,
//       onDidReceiveNotificationResponse: _onNotificationTapped,
//     );
//
//     // Demander les permissions
//     await _requestPermissions();
//
//     // Configurer le handler de messages en foreground
//     FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
//
//     // Configurer le handler quand on tape sur une notification
//     FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
//
//     // Vérifier si l'app a été ouverte via une notification
//     final initialMessage = await _messaging.getInitialMessage();
//     if (initialMessage != null) {
//       _handleNotificationOpen(initialMessage);
//     }
//
//     // Sauvegarder le token FCM
//     await _saveToken();
//
//     // Écouter les changements de token
//     _messaging.onTokenRefresh.listen(_onTokenRefresh);
//
//     _isInitialized = true;
//   }
//
//   Future<void> _requestPermissions() async {
//     final settings = await _messaging.requestPermission(
//       alert: true,
//       announcement: false,
//       badge: true,
//       carPlay: false,
//       criticalAlert: false,
//       provisional: false,
//       sound: true,
//     );
//
//     if (kDebugMode) {
//       print('Notification permission: ${settings.authorizationStatus}');
//     }
//   }
//
//   Future<void> _saveToken() async {
//     try {
//       final token = await _messaging.getToken();
//       if (token == null) return;
//
//       final user = FirebaseAuth.instance.currentUser;
//       if (user != null) {
//         await _firestore.collection('users').doc(user.uid).set({
//           'fcmToken': token,
//           'tokenUpdatedAt': FieldValue.serverTimestamp(),
//         }, SetOptions(merge: true));
//       }
//
//       // Sauvegarder aussi dans une collection de tokens pour les notifications de masse
//       await _firestore.collection('fcmTokens').doc(token).set({
//         'token': token,
//         'userId': user?.uid,
//         'platform': Platform.isIOS ? 'ios' : 'android',
//         'createdAt': FieldValue.serverTimestamp(),
//       }, SetOptions(merge: true));
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error saving FCM token: $e');
//       }
//     }
//   }
//
//   void _onTokenRefresh(String token) async {
//     await _saveToken();
//   }
//
//   void _handleForegroundMessage(RemoteMessage message) async {
//     if (kDebugMode) {
//       print('Foreground message received: ${message.notification?.title}');
//     }
//
//     // Sauvegarder la notification dans Firestore
//     await _saveNotificationToFirestore(message);
//
//     // Afficher une notification locale
//     await _showLocalNotification(message);
//   }
//
//   void _handleNotificationOpen(RemoteMessage message) {
//     // TODO: Naviguer vers l'écran approprié en fonction de la notification
//     final data = message.data;
//     final category = data['category'];
//     final itemId = data['itemId'];
//
//     if (kDebugMode) {
//       print('Notification opened: category=$category, itemId=$itemId');
//     }
//
//     // La navigation sera gérée par le callback défini dans main.dart
//   }
//
//   void _onNotificationTapped(NotificationResponse response) {
//     // Gérer le tap sur une notification locale
//     if (response.payload != null) {
//       try {
//         final data = json.decode(response.payload!);
//         final category = data['category'];
//         final itemId = data['itemId'];
//
//         if (kDebugMode) {
//           print('Local notification tapped: category=$category, itemId=$itemId');
//         }
//       } catch (_) {}
//     }
//   }
//
//   Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;
//
//     try {
//       await _firestore
//           .collection('users')
//           .doc(user.uid)
//           .collection('notifications')
//           .add({
//         'title': message.notification?.title ?? '',
//         'body': message.notification?.body ?? '',
//         'imageUrl': message.notification?.android?.imageUrl ??
//             message.notification?.apple?.imageUrl,
//         'timestamp': FieldValue.serverTimestamp(),
//         'category': message.data['category'],
//         'itemId': message.data['itemId'],
//         'isRead': false,
//       });
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error saving notification: $e');
//       }
//     }
//   }
//
//   Future<void> _showLocalNotification(RemoteMessage message) async {
//     const androidDetails = AndroidNotificationDetails(
//       'kin_city_channel',
//       'Kin City Guide',
//       channelDescription: 'Notifications de Kin City Guide',
//       importance: Importance.high,
//       priority: Priority.high,
//       showWhen: true,
//       icon: '@mipmap/ic_launcher',
//     );
//
//     const iosDetails = DarwinNotificationDetails(
//       presentAlert: true,
//       presentBadge: true,
//       presentSound: true,
//     );
//
//     const details = NotificationDetails(
//       android: androidDetails,
//       iOS: iosDetails,
//     );
//
//     await _localNotifications.show(
//       DateTime.now().millisecondsSinceEpoch.remainder(100000),
//       message.notification?.title ?? 'Nouvelle notification',
//       message.notification?.body ?? '',
//       details,
//       payload: json.encode(message.data),
//     );
//   }
//
//   // ============================================================
//   // FIRESTORE NOTIFICATIONS (historique)
//   // ============================================================
//
//   /// Stream des notifications de l'utilisateur courant
//   Stream<List<AppNotification>> watchUserNotifications() {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return Stream.value([]);
//
//     return _firestore
//         .collection('users')
//         .doc(user.uid)
//         .collection('notifications')
//         .orderBy('timestamp', descending: true)
//         .limit(50)
//         .snapshots()
//         .map((snapshot) {
//       return snapshot.docs
//           .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
//           .toList();
//     });
//   }
//
//   /// Stream des notifications globales (pour tous les utilisateurs)
//   Stream<List<AppNotification>> watchGlobalNotifications() {
//     return _firestore
//         .collection('notifications')
//         .orderBy('timestamp', descending: true)
//         .limit(50)
//         .snapshots()
//         .map((snapshot) {
//       return snapshot.docs
//           .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
//           .toList();
//     });
//   }
//
//   /// Marquer une notification comme lue
//   Future<void> markAsRead(String notificationId) async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;
//
//     await _firestore
//         .collection('users')
//         .doc(user.uid)
//         .collection('notifications')
//         .doc(notificationId)
//         .update({'isRead': true});
//   }
//
//   /// Marquer toutes les notifications comme lues
//   Future<void> markAllAsRead() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;
//
//     final batch = _firestore.batch();
//     final notifications = await _firestore
//         .collection('users')
//         .doc(user.uid)
//         .collection('notifications')
//         .where('isRead', isEqualTo: false)
//         .get();
//
//     for (final doc in notifications.docs) {
//       batch.update(doc.reference, {'isRead': true});
//     }
//
//     await batch.commit();
//   }
//
//   /// Supprimer une notification
//   Future<void> deleteNotification(String notificationId) async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;
//
//     await _firestore
//         .collection('users')
//         .doc(user.uid)
//         .collection('notifications')
//         .doc(notificationId)
//         .delete();
//   }
//
//   /// Nombre de notifications non lues
//   Stream<int> watchUnreadCount() {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return Stream.value(0);
//
//     return _firestore
//         .collection('users')
//         .doc(user.uid)
//         .collection('notifications')
//         .where('isRead', isEqualTo: false)
//         .snapshots()
//         .map((snapshot) => snapshot.docs.length);
//   }
//
//   // ============================================================
//   // ADMIN: Envoyer une notification (pour l'ajout d'éléments)
//   // ============================================================
//
//   /// Créer une notification globale quand un admin ajoute un élément
//   /// Cette méthode doit être appelée côté admin lors de l'ajout
//   static Future<void> sendNewItemNotification({
//     required String itemName,
//     required String category,
//     required String itemId,
//     String? imageUrl,
//   }) async {
//     final firestore = FirebaseFirestore.instance;
//
//     // Créer la notification globale
//     await firestore.collection('notifications').add({
//       'title': 'Nouveau lieu ajouté !',
//       'body': '$itemName vient d\'être ajouté dans la catégorie ${_getCategoryLabel(category)}',
//       'imageUrl': imageUrl,
//       'timestamp': FieldValue.serverTimestamp(),
//       'category': category,
//       'itemId': itemId,
//       'isGlobal': true,
//     });
//
//     // Distribuer à tous les utilisateurs avec un token FCM
//     // Note: Pour une vraie implémentation, utilisez Cloud Functions
//     // pour envoyer les notifications push via FCM Admin SDK
//   }
//
//   static String _getCategoryLabel(String category) {
//     switch (category) {
//       case 'sites':
//         return 'Sites touristiques';
//       case 'restaurants':
//         return 'Restaurants';
//       case 'hotels':
//         return 'Hôtels';
//       case 'events':
//         return 'Événements';
//       case 'entreprises':
//         return 'Entreprises';
//       case 'shoppings':
//         return 'Shopping';
//       default:
//         return category;
//     }
//   }
// }
//
// // ============================================================
// // RIVERPOD PROVIDERS
// // ============================================================
//
// final notificationServiceProvider = Provider<NotificationService>((ref) {
//   return NotificationService();
// });
//
// final userNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
//   final service = ref.watch(notificationServiceProvider);
//   return service.watchUserNotifications();
// });
//
// final globalNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
//   final service = ref.watch(notificationServiceProvider);
//   return service.watchGlobalNotifications();
// });
//
// final unreadNotificationCountProvider = StreamProvider<int>((ref) {
//   final service = ref.watch(notificationServiceProvider);
//   return service.watchUnreadCount();
// });
//
// /// Provider combiné pour toutes les notifications (user + global)
// final allNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
//   final userNotifs = ref.watch(userNotificationsProvider);
//   final globalNotifs = ref.watch(globalNotificationsProvider);
//
//   if (userNotifs.isLoading || globalNotifs.isLoading) {
//     return Stream.value([]);
//   }
//
//   final user = userNotifs.valueOrNull ?? [];
//   final global = globalNotifs.valueOrNull ?? [];
//
//   // Combiner et trier par timestamp
//   final combined = [...user, ...global];
//   combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
//
//   return Stream.value(combined);
// });