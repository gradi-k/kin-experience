class CommunityPost {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final List<String> media; // photos/vidéos
  final DateTime createdAt;

  const CommunityPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    this.media = const [],
    required this.createdAt,
  });

  factory CommunityPost.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v;
      try {
        // ignore: avoid_dynamic_calls
        return v.toDate() as DateTime;
      } catch (_) {
        return DateTime.tryParse(v.toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    return CommunityPost(
      id: (map['id'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      userName: (map['userName'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      media: (map['media'] is List)
          ? (map['media'] as List).map((e) => e.toString()).toList()
          : const [],
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'text': text,
    'media': media,
    'createdAt': createdAt,
  };
}
