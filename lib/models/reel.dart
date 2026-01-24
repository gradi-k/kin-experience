// lib/models/reel.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Reel {
  final String id;
  final String videoUrl;
  final String authorName;
  final String authorAvatar;
  final String caption;
  final String location;
  final int likes;
  final int comments;
  final String? musicLabel;

  // ✅ Nouveaux champs pour lier à un lieu
  final String? placeId;
  final String? placeCategory; // 'site', 'hotel', 'resto', 'event', 'entreprise', 'shopping'
  final String? placeName;

  // ✅ Métadonnées
  final DateTime? createdAt;
  final String? createdBy;
  final bool isActive;

  const Reel({
    required this.id,
    required this.videoUrl,
    required this.authorName,
    required this.authorAvatar,
    required this.caption,
    required this.location,
    this.likes = 0,
    this.comments = 0,
    this.musicLabel,
    this.placeId,
    this.placeCategory,
    this.placeName,
    this.createdAt,
    this.createdBy,
    this.isActive = true,
  });

  /// ✅ Factory pour créer depuis Firestore
  factory Reel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return Reel(
      id: doc.id,
      videoUrl: (data['videoUrl'] ?? '').toString(),
      authorName: (data['authorName'] ?? 'Utilisateur').toString(),
      authorAvatar: (data['authorAvatar'] ?? '').toString(),
      caption: (data['caption'] ?? '').toString(),
      location: (data['location'] ?? '').toString(),
      likes: (data['likes'] is num) ? (data['likes'] as num).toInt() : 0,
      comments: (data['comments'] is num) ? (data['comments'] as num).toInt() : 0,
      musicLabel: data['musicLabel']?.toString(),
      placeId: data['placeId']?.toString(),
      placeCategory: data['placeCategory']?.toString(),
      placeName: data['placeName']?.toString(),
      createdAt: parseDate(data['createdAt']),
      createdBy: data['createdBy']?.toString(),
      isActive: data['isActive'] == true,
    );
  }

  /// ✅ Factory pour créer depuis un Map
  factory Reel.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return Reel(
      id: id ?? (map['id'] ?? '').toString(),
      videoUrl: (map['videoUrl'] ?? '').toString(),
      authorName: (map['authorName'] ?? 'Utilisateur').toString(),
      authorAvatar: (map['authorAvatar'] ?? '').toString(),
      caption: (map['caption'] ?? '').toString(),
      location: (map['location'] ?? '').toString(),
      likes: (map['likes'] is num) ? (map['likes'] as num).toInt() : 0,
      comments: (map['comments'] is num) ? (map['comments'] as num).toInt() : 0,
      musicLabel: map['musicLabel']?.toString(),
      placeId: map['placeId']?.toString(),
      placeCategory: map['placeCategory']?.toString(),
      placeName: map['placeName']?.toString(),
      createdAt: parseDate(map['createdAt']),
      createdBy: map['createdBy']?.toString(),
      isActive: map['isActive'] != false,
    );
  }

  /// ✅ Convertir en Map pour Firestore
  Map<String, dynamic> toMap() => {
    'videoUrl': videoUrl,
    'authorName': authorName,
    'authorAvatar': authorAvatar,
    'caption': caption,
    'location': location,
    'likes': likes,
    'comments': comments,
    'musicLabel': musicLabel,
    'placeId': placeId,
    'placeCategory': placeCategory,
    'placeName': placeName,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    'createdBy': createdBy,
    'isActive': isActive,
  };

  /// ✅ Copie avec modifications
  Reel copyWith({
    String? id,
    String? videoUrl,
    String? authorName,
    String? authorAvatar,
    String? caption,
    String? location,
    int? likes,
    int? comments,
    String? musicLabel,
    String? placeId,
    String? placeCategory,
    String? placeName,
    DateTime? createdAt,
    String? createdBy,
    bool? isActive,
  }) {
    return Reel(
      id: id ?? this.id,
      videoUrl: videoUrl ?? this.videoUrl,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      musicLabel: musicLabel ?? this.musicLabel,
      placeId: placeId ?? this.placeId,
      placeCategory: placeCategory ?? this.placeCategory,
      placeName: placeName ?? this.placeName,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
    );
  }

  /// ✅ Vérifie si le reel est lié à un lieu
  bool get hasLinkedPlace => placeId != null && placeId!.isNotEmpty && placeCategory != null;
}

/// ✅ Modèle pour les commentaires avec réponses
class ReelComment {
  final String id;
  final String reelId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String text;
  final DateTime? createdAt;
  final String? parentId; // ✅ Pour les réponses
  final int replyCount;

  const ReelComment({
    required this.id,
    required this.reelId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.text,
    this.createdAt,
    this.parentId,
    this.replyCount = 0,
  });

  factory ReelComment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return ReelComment(
      id: doc.id,
      reelId: (data['reelId'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? 'Utilisateur').toString(),
      userPhotoUrl: data['userPhotoUrl']?.toString(),
      text: (data['text'] ?? '').toString(),
      createdAt: parseDate(data['createdAt']),
      parentId: data['parentId']?.toString(),
      replyCount: (data['replyCount'] is num) ? (data['replyCount'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'reelId': reelId,
    'userId': userId,
    'userName': userName,
    'userPhotoUrl': userPhotoUrl,
    'text': text,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    'parentId': parentId,
    'replyCount': replyCount,
  };

  bool get isReply => parentId != null && parentId!.isNotEmpty;
}