import '../models/reel.dart';

final List<Reel> fakeReels = [
  const Reel(
    id: 'r1',
    videoUrl: 'assets/videos/vid-4.mp4',
    authorName: 'Noah Nkulu',
    authorAvatar: 'assets/images/avatars/avatar_1.jpg',
    caption: 'Le meilleur pondu de Kinshasa ! Ambiance familiale et saveurs authentiques',
    location: 'Chez Ntemba',
    likes: 342,
    comments: 28,
    musicLabel: 'Son original',
  ),
  const Reel(
    id: 'r2',
    videoUrl: 'assets/videos/vid-3.mp4',
    authorName: 'Luc Amani',
    authorAvatar: 'assets/images/avatars/avatar_2.jpg',
    caption: 'Soirée live à Gombe. Entrée libre avant 22h.',
    location: 'Gombe',
    likes: 120,
    comments: 9,
    musicLabel: 'Afrobeat',
  ),
  const Reel(
    id: 'r3',
    videoUrl: 'assets/videos/vid-2.mp4',
    authorName: 'DJ Mapendo',
    authorAvatar: 'assets/images/avatars/avatar_3.jpg',
    caption: 'Vibes du weekend. Qui vient ?',
    location: 'Matonge',
    likes: 980,
    comments: 76,
    musicLabel: 'Mix live',
  ),
];
