// lib/views/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../controllers/notification_controller.dart';
import '../../models/app_notification.dart';
import '../../services/notification_service.dart' hide allNotificationsProvider;
import '../../controllers/places_controller.dart';
import '../../models/place_enums.dart';
import '../detail_screen.dart';

/// Écran des notifications - Version dynamique avec Firebase.
/// Affiche les notifications de l'utilisateur et les notifications globales.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ✅ Récupérer les notifications combinées (user + global)
    final notificationsAsync = ref.watch(allNotificationsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          "Notifications",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          // Bouton pour marquer tout comme lu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'mark_all_read') {
                await NotificationService().markAllAsRead();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Toutes les notifications marquées comme lues'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all, size: 20),
                    SizedBox(width: 8),
                    Text('Tout marquer comme lu'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return _buildEmptyState(theme);
          }

          // Grouper les notifications par date
          final grouped = _groupByDate(notifications);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final group = grouped[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0) const SizedBox(height: 16),
                  _sectionTitle(context, group.title),
                  const SizedBox(height: 10),
                  ...group.notifications.map((notif) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _notificationTile(context, notif),
                  )),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        // ✅ Message générique au lieu d'erreur technique
        error: (e, _) => _buildEmptyState(theme),
      ),
    );
  }

  /// ✅ État vide avec message générique et convivial
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune notification',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vous recevrez des notifications lorsque de nouveaux lieux seront ajoutés ou pour des offres spéciales.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_NotificationGroup> _groupByDate(List<AppNotification> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeek = today.subtract(const Duration(days: 7));
    final thisMonth = DateTime(now.year, now.month, 1);

    final todayList = <AppNotification>[];
    final yesterdayList = <AppNotification>[];
    final thisWeekList = <AppNotification>[];
    final thisMonthList = <AppNotification>[];
    final olderList = <AppNotification>[];

    for (final notif in notifications) {
      // ✅ Utiliser createdAt au lieu de timestamp
      final date = DateTime(
        notif.createdAt.year,
        notif.createdAt.month,
        notif.createdAt.day,
      );

      if (date.isAtSameMomentAs(today)) {
        todayList.add(notif);
      } else if (date.isAtSameMomentAs(yesterday)) {
        yesterdayList.add(notif);
      } else if (date.isAfter(thisWeek)) {
        thisWeekList.add(notif);
      } else if (date.isAfter(thisMonth)) {
        thisMonthList.add(notif);
      } else {
        olderList.add(notif);
      }
    }

    final groups = <_NotificationGroup>[];
    if (todayList.isNotEmpty) {
      groups.add(_NotificationGroup(title: "Aujourd'hui", notifications: todayList));
    }
    if (yesterdayList.isNotEmpty) {
      groups.add(_NotificationGroup(title: 'Hier', notifications: yesterdayList));
    }
    if (thisWeekList.isNotEmpty) {
      groups.add(_NotificationGroup(title: 'Cette semaine', notifications: thisWeekList));
    }
    if (thisMonthList.isNotEmpty) {
      groups.add(_NotificationGroup(title: 'Ce mois', notifications: thisMonthList));
    }
    if (olderList.isNotEmpty) {
      groups.add(_NotificationGroup(title: 'Plus ancien', notifications: olderList));
    }

    return groups;
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: theme.textTheme.titleSmall?.color?.withOpacity(0.6),
      ),
    );
  }

  Widget _notificationTile(BuildContext context, AppNotification notification) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMM yyyy • HH:mm', 'fr_FR');

    // Déterminer la couleur du titre basée sur le contenu
    Color? titleColor;
    if (notification.title.toLowerCase().contains('nouveau')) {
      titleColor = Colors.green;
    } else if (notification.title.toLowerCase().contains('promotion') ||
        notification.title.toLowerCase().contains('réduction')) {
      titleColor = Colors.orange;
    }

    // Déterminer l'icône basée sur la catégorie
    IconData icon = Icons.notifications;
    if (notification.category != null) {
      switch (notification.category) {
        case 'sites':
          icon = Icons.landscape;
          break;
        case 'restaurants':
        case 'restos':
          icon = Icons.restaurant;
          break;
        case 'hotels':
          icon = Icons.hotel;
          break;
        case 'events':
          icon = Icons.event;
          break;
        case 'entreprises':
          icon = Icons.home_work;
          break;
        case 'shoppings':
        case 'shopping':
          icon = Icons.shopping_bag;
          break;
      }
    }

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      onDismissed: (_) async {
        await NotificationService().deleteNotification(notification.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification supprimée'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: InkWell(
        onTap: () async {
          // Marquer comme lu
          if (!notification.isRead) {
            await NotificationService().markAsRead(notification.id);
          }

          // ✅ Naviguer vers le détail si category et placeId sont présents
          if (notification.category != null && notification.placeId != null) {
            _navigateToItem(context, notification.category!, notification.placeId!);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.transparent
                : theme.colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: notification.isRead
                  ? theme.dividerColor.withOpacity(0.1)
                  : theme.colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image ou icône
              if (notification.imageUrl != null &&
                  notification.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    notification.imageUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _iconFallback(theme, icon),
                  ),
                )
              else
                _iconFallback(theme, icon),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: titleColor ?? theme.textTheme.titleSmall?.color,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Date et heure
                    Text(
                      dateFormat.format(notification.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ✅ Corps de la notification - Amélioré pour plus de visibilité
                    Text(
                      notification.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconFallback(ThemeData theme, IconData icon) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: theme.colorScheme.primary,
        size: 24,
      ),
    );
  }

  void _navigateToItem(BuildContext context, String category, String itemId) async {
    // Déterminer la catégorie
    PlaceCategory? placeCategory;
    switch (category) {
      case 'sites':
        placeCategory = PlaceCategory.site;
        break;
      case 'restaurants':
      case 'restos':
        placeCategory = PlaceCategory.resto;
        break;
      case 'hotels':
        placeCategory = PlaceCategory.hotel;
        break;
      case 'events':
        placeCategory = PlaceCategory.event;
        break;
      case 'entreprises':
        placeCategory = PlaceCategory.entreprise;
        break;
      case 'shoppings':
      case 'shopping':
        placeCategory = PlaceCategory.shopping;
        break;
    }

    if (placeCategory == null) return;

    // Récupérer l'item depuis Firebase
    try {
      final repo = ref.read(placesRepositoryProvider);
      final place = await repo.getPlaceById(placeCategory, itemId);

      if (place != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetailScreen(
              place: place,
              category: placeCategory!,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de charger l\'élément: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _NotificationGroup {
  final String title;
  final List<AppNotification> notifications;

  const _NotificationGroup({
    required this.title,
    required this.notifications,
  });
}