class Reel {
  final String id;
  final String videoUrl; // network mp4 ou asset
  final String authorName;
  final String authorAvatar; // asset ou url
  final String caption;
  final String location;
  final int likes;
  final int comments;
  final String? musicLabel;

  const Reel({
    required this.id,
    required this.videoUrl,
    required this.authorName,
    required this.authorAvatar,
    required this.caption,
    required this.location,
    required this.likes,
    required this.comments,
    this.musicLabel,
  });
}
