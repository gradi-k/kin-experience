class FakeAd {
  final String id;
  final String title;
  final String subtitle;
  final String image; // asset ou url
  final String? ctaLabel;
  final String? link; // lien externe
  final bool isActive;

  const FakeAd({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.image,
    this.ctaLabel,
    this.link,
    this.isActive = true,
  });
}

/// Fake ads (à remplacer plus tard par API/Firestore)
final List<FakeAd> fakeAds = [
  FakeAd(
    id: 'ad1',
    title: 'Promo Week-End',
    subtitle: 'Réductions sur hôtels et restos partenaires',
    image: 'assets/images/ads/ad1.jpg',
    ctaLabel: 'Découvrir',
    link: 'https://example.com/promo',
  ),
  FakeAd(
    id: 'ad2',
    title: 'Kin-Experience Pass',
    subtitle: 'Accès VIP + avantages exclusifs',
    image: 'assets/images/ads/ad2.jpg',
    ctaLabel: 'En savoir plus',
    link: 'https://example.com/pass',
  ),
  FakeAd(
    id: 'ad3',
    title: 'Événements cette semaine',
    subtitle: 'Concerts, soirées, festivals',
    image: 'assets/images/ads/ad3.jpg',
    ctaLabel: 'Voir',
    link: 'https://example.com/events',
  ),
];
