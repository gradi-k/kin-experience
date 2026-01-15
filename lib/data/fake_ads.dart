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
    image: 'assets/images/ads/Ads-1.png',
    ctaLabel: 'Boutique',
    link: 'https://ministere.labelflow.cloud/',
  ),
  FakeAd(
    id: 'ad2',
    title: 'Kin-Experience Pass',
    subtitle: 'Accès VIP + avantages exclusifs',
    image: 'assets/images/ads/Ads-2.png',
    // ctaLabel: 'En savoir plus',
    link: 'https://example.com/pass',
  ),
  FakeAd(
    id: 'ad3',
    title: 'Événements cette semaine',
    subtitle: 'Concerts, soirées, festivals',
    image: 'assets/images/ads/Ads-3.png',
    // ctaLabel: 'Voir',
    link: 'https://example.com/events',
  ),
  FakeAd(
    id: 'ad4',
    title: 'Événements cette semaine',
    subtitle: 'Concerts, soirées, festivals',
    image: 'assets/images/ads/Ads-4.png',
    // ctaLabel: 'Voir',
    link: 'https://example.com/events',
  ),
  FakeAd(
    id: 'ad5',
    title: 'Événements cette semaine',
    subtitle: 'Concerts, soirées, festivals',
    image: 'assets/images/ads/Ads-5.png',
    // ctaLabel: 'Voir',
    link: 'https://example.com/events',
  ),
  FakeAd(
    id: 'ad6',
    title: 'Événements cette semaine',
    subtitle: 'Concerts, soirées, festivals',
    image: 'assets/images/ads/Ads-6.png',
    // ctaLabel: 'Voir',
    link: 'https://example.com/events',
  ),

];
