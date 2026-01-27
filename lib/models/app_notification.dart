import 'package:cloud_firestore/cloud_firestore.dart';

/// Types de notifications possibles
enum NotificationType {
  newPlace,      // Nouveau lieu ajouté
  newEvent,      // Nouvel événement
  promo,         // Promotion
  system,        // Notification système
  update,        // Mise à jour d'un lieu
}

/// Modèle de notification pour l'application
class AppNotification {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final NotificationType type;
  final String? placeId;         // ID du lieu concerné (si applicable)
  final String? placeName;       // Nom du lieu (pour affichage rapide)
  final String? category;        // Catégorie du lieu (hotels, restos, etc.)
  final DateTime createdAt;
  final bool isRead;
  final String? targetUserId;    // null = tous les utilisateurs

  const AppNotification({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.type,
    this.placeId,
    this.placeName,
    this.category,
    required this.createdAt,
    this.isRead = false,
    this.targetUserId,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    return AppNotification(
      id: id,
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      imageUrl: map['imageUrl']?.toString(),
      type: _parseNotificationType(map['type']?.toString()),
      placeId: map['placeId']?.toString(),
      placeName: map['placeName']?.toString(),
      category: map['category']?.toString(),
      createdAt: _parseDateTime(map['createdAt']),
      isRead: (map['isRead'] ?? false) as bool,
      targetUserId: map['targetUserId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'type': type.name,
      'placeId': placeId,
      'placeName': placeName,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'targetUserId': targetUserId,
    };
  }

  /// Crée une copie avec des modifications
  AppNotification copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    NotificationType? type,
    String? placeId,
    String? placeName,
    String? category,
    DateTime? createdAt,
    bool? isRead,
    String? targetUserId,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      placeId: placeId ?? this.placeId,
      placeName: placeName ?? this.placeName,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      targetUserId: targetUserId ?? this.targetUserId,
    );
  }

  static NotificationType _parseNotificationType(String? value) {
    switch (value) {
      case 'newPlace':
        return NotificationType.newPlace;
      case 'newEvent':
        return NotificationType.newEvent;
      case 'promo':
        return NotificationType.promo;
      case 'system':
        return NotificationType.system;
      case 'update':
        return NotificationType.update;
      default:
        return NotificationType.system;
    }
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  /// Formatte la date de manière lisible
  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) {
      return "À l'instant";
    } else if (diff.inMinutes < 60) {
      return "Il y a ${diff.inMinutes} min";
    } else if (diff.inHours < 24) {
      return "Il y a ${diff.inHours}h";
    } else if (diff.inDays == 1) {
      return "Hier";
    } else if (diff.inDays < 7) {
      return "Il y a ${diff.inDays} jours";
    } else {
      return "${createdAt.day}/${createdAt.month}/${createdAt.year}";
    }
  }

  /// Retourne l'icône appropriée selon le type
  String get iconName {
    switch (type) {
      case NotificationType.newPlace:
        return 'place';
      case NotificationType.newEvent:
        return 'event';
      case NotificationType.promo:
        return 'local_offer';
      case NotificationType.system:
        return 'info';
      case NotificationType.update:
        return 'update';
    }
  }
}