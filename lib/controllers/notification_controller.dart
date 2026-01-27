// lib/controllers/notification_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SERVICE PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// ═══════════════════════════════════════════════════════════════════════════
// STREAM PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Provider pour les notifications de l'utilisateur connecté
final userNotificationsProvider =
StreamProvider<List<AppNotification>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.watchUserNotifications();
});

/// Provider pour les notifications globales
final globalNotificationsProvider =
StreamProvider<List<AppNotification>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.watchGlobalNotifications();
});

// ✅ AJOUTÉ : Provider pour TOUTES les notifications (user + global)
/// Provider qui combine les notifications utilisateur ET globales
final allNotificationsProvider =
StreamProvider<List<AppNotification>>((ref) async* {
  final service = ref.watch(notificationServiceProvider);

  // Combine les deux streams
  await for (final userNotifs in service.watchUserNotifications()) {
    final globalNotifs = await service.watchGlobalNotifications().first;

    // Fusionner et trier par date (plus récent en premier)
    final allNotifs = [...userNotifs, ...globalNotifs];
    allNotifs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    yield allNotifs;
  }
});

/// Provider pour le nombre de notifications non lues
final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.watchUnreadCount();
});

// ═══════════════════════════════════════════════════════════════════════════
// NOTIFIER POUR LES ACTIONS
// ═══════════════════════════════════════════════════════════════════════════

class NotificationActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final NotificationService _service;

  NotificationActionsNotifier(this._service) : super(const AsyncValue.data(null));

  /// Marque une notification comme lue
  Future<void> markAsRead(String notificationId) async {
    state = const AsyncValue.loading();
    try {
      await _service.markAsRead(notificationId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Marque toutes les notifications comme lues
  Future<void> markAllAsRead() async {
    state = const AsyncValue.loading();
    try {
      await _service.markAllAsRead();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Supprime une notification
  Future<void> deleteNotification(String notificationId) async {
    state = const AsyncValue.loading();
    try {
      await _service.deleteNotification(notificationId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final notificationActionsProvider =
StateNotifierProvider<NotificationActionsNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return NotificationActionsNotifier(service);
});

// ═══════════════════════════════════════════════════════════════════════════
// NOTIFICATIONS GROUPÉES PAR DATE
// ═══════════════════════════════════════════════════════════════════════════

/// Structure pour les notifications groupées
class NotificationGroup {
  final String title;
  final List<AppNotification> notifications;

  const NotificationGroup({
    required this.title,
    required this.notifications,
  });
}

/// Provider pour les notifications groupées par date
final groupedNotificationsProvider =
Provider<AsyncValue<List<NotificationGroup>>>((ref) {
  final notificationsAsync = ref.watch(allNotificationsProvider);  // ✅ Utilise allNotificationsProvider

  return notificationsAsync.when(
    data: (notifications) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final weekAgo = today.subtract(const Duration(days: 7));

      final todayNotifs = <AppNotification>[];
      final yesterdayNotifs = <AppNotification>[];
      final thisWeekNotifs = <AppNotification>[];
      final olderNotifs = <AppNotification>[];

      for (final notif in notifications) {
        final notifDate = DateTime(
          notif.createdAt.year,
          notif.createdAt.month,
          notif.createdAt.day,
        );

        if (notifDate.isAtSameMomentAs(today) || notifDate.isAfter(today)) {
          todayNotifs.add(notif);
        } else if (notifDate.isAtSameMomentAs(yesterday)) {
          yesterdayNotifs.add(notif);
        } else if (notifDate.isAfter(weekAgo)) {
          thisWeekNotifs.add(notif);
        } else {
          olderNotifs.add(notif);
        }
      }

      final groups = <NotificationGroup>[];

      if (todayNotifs.isNotEmpty) {
        groups.add(NotificationGroup(
          title: "Aujourd'hui",
          notifications: todayNotifs,
        ));
      }

      if (yesterdayNotifs.isNotEmpty) {
        groups.add(NotificationGroup(
          title: 'Hier',
          notifications: yesterdayNotifs,
        ));
      }

      if (thisWeekNotifs.isNotEmpty) {
        groups.add(NotificationGroup(
          title: 'Cette semaine',
          notifications: thisWeekNotifs,
        ));
      }

      if (olderNotifs.isNotEmpty) {
        groups.add(NotificationGroup(
          title: 'Plus ancien',
          notifications: olderNotifs,
        ));
      }

      return AsyncValue.data(groups);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});