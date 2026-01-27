import 'package:cloud_firestore/cloud_firestore.dart';

/// Types de notifications possibles
enum NotificationType {
  newPlace, // Nouveau lieu ajouté
  newEvent, // Nouvel événement
  promo, // Promotion
  system, // Notification système
  update, // Mise à jour d'un lieu
}

/// Modèle de notification pour l'application
class AppNotification {
  final String id;

  /// Toujours présent en UI (fallback si champ manquant)
  final String title;

  /// Texte principal (supporte: `description` OU `body`)
  final String description;

  final String? imageUrl;

  /// Type logique, peut venir de `type` ou être déduit de `category`
  final NotificationType type;

  /// ID de l'objet cible (supporte: `placeId` OU `itemId`)
  final String? placeId;

  final String? placeName;

  /// Catégorie (hotels, restaurants, events, etc.)
  final String? category;

  /// Date (supporte: `createdAt` OU `timestamp`)
  final DateTime createdAt;

  final bool isRead;

  /// null = notification globale pour tous
  final String? targetUserId;

  /// Optionnel mais utile si vous le stockez
  final bool isGlobal;

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
    this.isGlobal = false,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    final String title = (map['title'] ?? '').toString().trim();

    // Supporte `description` (ancien) OU `body` (Cloud Functions)
    final String description =
    (map['description'] ?? map['body'] ?? '').toString().trim();

    // Supporte `createdAt` OU `timestamp`
    final DateTime createdAt =
    _parseDateTime(map['createdAt'] ?? map['timestamp']);

    // Supporte `placeId` OU `itemId`
    final String? placeId = _nullableString(map['placeId'] ?? map['itemId']);

    // targetUserId: transforme "" -> null
    final String? targetUserId = _nullableString(map['targetUserId']);

    // isGlobal: si stocké, sinon on l'infère
    final bool isGlobal =
        (map['isGlobal'] == true) || (targetUserId == null);

    // category
    final String? category = _nullableString(map['category']);

    // type: lit `type` si présent, sinon déduit de category
    final NotificationType type = _parseNotificationType(
      _nullableString(map['type']),
      category: category,
    );

    return AppNotification(
      id: id,
      title: title.isEmpty ? 'Notification' : title,
      description: description,
      imageUrl: _nullableString(map['imageUrl']),
      type: type,
      placeId: placeId,
      placeName: _nullableString(map['placeName']),
      category: category,
      createdAt: createdAt,
      isRead: _parseBool(map['isRead']) ?? false,
      targetUserId: targetUserId,
      isGlobal: isGlobal,
    );
  }

  Map<String, dynamic> toMap() {
    // On écrit un schéma unifié recommandé.
    // (Vous pouvez continuer à écrire `body` côté functions, mais pour Flutter,
    // préférez `description` + `createdAt` partout.)
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
      'isGlobal': isGlobal,
    };
  }

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
    bool? isGlobal,
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
      isGlobal: isGlobal ?? this.isGlobal,
    );
  }

  // -------------------------
  // Helpers parsing
  // -------------------------

  static String? _nullableString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return s;
  }

  static bool? _parseBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return null;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  static NotificationType _parseNotificationType(
      String? value, {
        String? category,
      }) {
    // 1) Si `type` existe, on le respecte
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
    }

    // 2) Sinon, déduction simple par category
    if (category == null) return NotificationType.system;

    if (category == 'events') return NotificationType.newEvent;
    if (category == 'restaurants' ||
        category == 'hotels' ||
        category == 'sites' ||
        category == 'entreprises' ||
        category == 'shoppings' ||
        category == 'places') {
      return NotificationType.newPlace;
    }

    return NotificationType.system;
  }

  // -------------------------
  // UI helpers
  // -------------------------

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return "Il y a ${diff.inMinutes} min";
    if (diff.inHours < 24) return "Il y a ${diff.inHours}h";
    if (diff.inDays == 1) return "Hier";
    if (diff.inDays < 7) return "Il y a ${diff.inDays} jours";
    return "${createdAt.day}/${createdAt.month}/${createdAt.year}";
  }

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
