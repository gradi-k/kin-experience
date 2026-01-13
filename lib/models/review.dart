class Review {
  final String id;
  final String userId;
  final String userName;
  final double rating; // 0..5
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v;
      // Firestore Timestamp support (sans import direct)
      final ts = v;
      try {
        // ignore: avoid_dynamic_calls
        return ts.toDate() as DateTime;
      } catch (_) {
        return DateTime.tryParse(v.toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    return Review(
      id: (map['id'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      userName: (map['userName'] ?? '').toString(),
      rating: (map['rating'] is num) ? (map['rating'] as num).toDouble() : 0.0,
      comment: (map['comment'] ?? '').toString(),
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'rating': rating,
    'comment': comment,
    'createdAt': createdAt,
  };
}
