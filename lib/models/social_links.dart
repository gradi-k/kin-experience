class SocialLinks {
  final String? facebookUrl;
  final String? instagramUrl;
  final String? tiktokUrl;

  const SocialLinks({
    this.facebookUrl,
    this.instagramUrl,
    this.tiktokUrl,
  });

  factory SocialLinks.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const SocialLinks();
    return SocialLinks(
      facebookUrl: map['facebookUrl'] as String?,
      instagramUrl: map['instagramUrl'] as String?,
      tiktokUrl: map['tiktokUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'facebookUrl': facebookUrl,
    'instagramUrl': instagramUrl,
    'tiktokUrl': tiktokUrl,
  }..removeWhere((k, v) => v == null);

  bool get isEmpty =>
      (facebookUrl == null || facebookUrl!.trim().isEmpty) &&
          (instagramUrl == null || instagramUrl!.trim().isEmpty) &&
          (tiktokUrl == null || tiktokUrl!.trim().isEmpty);
}
