import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical Ads model used across the app.
/// Keep field names aligned with your previous FakeAd structure.
class AdModel {
  final String id;
  final String title;
  final String subtitle;
  /// Can be an asset path (legacy) or a network URL (Firebase Storage download URL).
  final String image;
  final String ctaLabel;
  final String link;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.ctaLabel,
    required this.link,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  AdModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? image,
    String? ctaLabel,
    String? link,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      image: image ?? this.image,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      link: link ?? this.link,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'image': image,
      'ctaLabel': ctaLabel,
      'link': link,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static AdModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};

    DateTime tsToDt(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return AdModel(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      subtitle: (d['subtitle'] ?? '').toString(),
      image: (d['image'] ?? '').toString(),
      ctaLabel: (d['ctaLabel'] ?? '').toString(),
      link: (d['link'] ?? '').toString(),
      isActive: (d['isActive'] ?? true) == true,
      createdAt: tsToDt(d['createdAt']),
      updatedAt: tsToDt(d['updatedAt']),
    );
  }
}
