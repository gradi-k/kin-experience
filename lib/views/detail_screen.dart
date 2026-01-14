import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/favorites_controller.dart';
import '../localization/app_localizations.dart';
import '../data/fake_data.dart';
import '../models/place_enums.dart';
import '../utils/constants.dart';

// NOTE: On évite Constants.kinGold/kinBlue car ça cassait ton build.
// Si tu tiens à Constants, tu peux les remettre après avoir ajouté ces couleurs dans constants.dart.

class DetailScreen extends ConsumerWidget {
  final dynamic place;
  final PlaceCategory category;

  const DetailScreen({
    Key? key,
    required this.place,
    required this.category,
  }) : super(key: key);

  // ---------------------------
  // Helpers "safe" (évite NoSuchMethodError si le champ n’existe pas)
  // ---------------------------
  T? _tryGet<T>(T Function() getter) {
    try {
      return getter();
    } catch (_) {
      return null;
    }
  }

  String get _name => _tryGet(() => place.nom.toString()) ?? '—';

  String get _desc => _tryGet(() => place.description.toString()) ?? '';

  double get _rating => _tryGet(() => (place.rating as double)) ?? 0.0;

  String get _price => _tryGet(() => place.prixRange.toString()) ?? '—';

  double get _lat => _tryGet(() => (place.latitude as double)) ?? 0.0;

  double get _lng => _tryGet(() => (place.longitude as double)) ?? 0.0;

  List<dynamic> get _photos =>
      _tryGet(() => (place.photos as List))?.toList() ?? const [];

  // Champs optionnels
  String? get _address => _tryGet<String?>(() => place.address as String?);

  String? get _phone => _tryGet<String?>(() => place.phone as String?);

  String? get _email => _tryGet<String?>(() => place.email as String?);

  String? get _website => _tryGet<String?>(() => place.website as String?);

  String? get _facebookUrl =>
      _tryGet<String?>(() => place.facebookUrl as String?);

  String? get _instagramUrl =>
      _tryGet<String?>(() => place.instagramUrl as String?);

  String? get _tiktokUrl => _tryGet<String?>(() => place.tiktokUrl as String?);

  List<String> get _amenities =>
      _tryGet(() => (place.amenities as List).cast<String>()) ??
          const <String>[];

  String? get _schedule => _tryGet<String?>(() => place.schedule as String?);

  int get _reviewCount => _tryGet(() => place.reviewCount as int) ?? 0;

  double get _distanceKm => _tryGet(() => place.distanceKm as double) ?? 0.0;

  bool get _isEvent => category == PlaceCategory.event;

  // Thème colors fallback (pour éviter tes erreurs de Constants)
  Color _gold(BuildContext context) => const Color(0xFFD2A100);

  Color _blue(BuildContext context) => const Color(0xFF0B5ED7);

  // ---------------------------
  // Actions externes
  // ---------------------------
  Future<void> _openExternalLink(BuildContext context, String? url) async {
    final value = (url ?? '').trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lien indisponible")),
      );
      return;
    }
    final uri = Uri.tryParse(value);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lien invalide")),
      );
      return;
    }
    if (!await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d’ouvrir le lien")),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openMaps() async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$_lat,$_lng';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPhone() async {
    final phone = (_phone ?? '').trim();
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendEmail() async {
    final email = (_email ?? '').trim();
    if (email.isEmpty) return;
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ---------------------------
  // Similar content (basé sur fake_data)
  // ---------------------------
  List<dynamic> _getSimilarItems() {
    List<dynamic> source;
    switch (category) {
      case PlaceCategory.site:
        source = fakeSites;
        break;
      case PlaceCategory.resto:
        source = fakeRestos;
        break;
      case PlaceCategory.hotel:
        source = fakeHotels;
        break;
      case PlaceCategory.event:
        source = fakeEvents;
        break;
      case PlaceCategory.entreprise:
        source = fakeEntreprises;
        break;
      case PlaceCategory.shopping:
        source = fakeShoppings; // IMPORTANT: ta liste est sans "s"
        break;
    }

    final currentId = _tryGet(() => place.id.toString()) ?? '';
    final items = source.where((e) {
      final id = _tryGet(() => e.id.toString()) ?? '';
      return id != currentId;
    }).toList();

    return items.take(6).toList();
  }

  String _categoryLabel(AppLocalizations loc) {
    switch (category) {
      case PlaceCategory.site:
        return loc.translate('sites_label');
      case PlaceCategory.resto:
        return loc.translate('restos_label');
      case PlaceCategory.hotel:
        return loc.translate('hotels_label');
      case PlaceCategory.event:
        return loc.translate('events_label');
      case PlaceCategory.entreprise:
        return 'Immo';
      case PlaceCategory.shopping:
        return 'Shopping';
    }
  }

  IconData _categoryIcon() {
    switch (category) {
      case PlaceCategory.hotel:
        return Icons.hotel;
      case PlaceCategory.resto:
        return Icons.restaurant;
      case PlaceCategory.event:
        return Icons.celebration;
      case PlaceCategory.site:
        return Icons.landscape;
      case PlaceCategory.entreprise:
        return Icons.home_work;
      case PlaceCategory.shopping:
        return Icons.shopping_bag;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final favoritesState = ref.watch(favoritesControllerProvider);
    final favoritesNotifier = ref.read(favoritesControllerProvider.notifier);

    final isFav = favoritesState.maybeWhen(
      data: (list) => favoritesNotifier.isFavorite(place, category),
      orElse: () => false,
    );

    final similar = _getSimilarItems();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 260,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: Text(
                    _name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border),
                      onPressed: () async {
                        await favoritesNotifier.toggleFavorite(place, category);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () {
                        // TODO share_plus
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_photos.isNotEmpty)
                          PageView.builder(
                            itemCount: _photos.length,
                            itemBuilder: (context, index) {
                              final p = _photos[index].toString();
                              return p.startsWith('assets/')
                                  ? Image.asset(p, fit: BoxFit.cover)
                                  : Image.network(p, fit: BoxFit.cover);
                            },
                          )
                        else
                          Container(color: theme.cardColor),

                        // Gradient lisibilité (mais sans titre)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 110,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.55),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),

                        // Bouton “Voir toutes les photos” — on le remonte un peu pour éviter chevauchement
                        Positioned(
                          right: 14,
                          bottom: 18,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.cardColor.withOpacity(
                                  0.92),
                              foregroundColor: theme.textTheme.bodyMedium
                                  ?.color,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PhotoGalleryScreen(photos: _photos),
                                ),
                              );
                            },
                            icon: const Icon(
                                Icons.photo_library_outlined, size: 18),
                            label: const Text('Voir toutes les photos'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bloc Titre + meta (hors image) = plus de superposition
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _MetaPill(
                              icon: _categoryIcon(),
                              text: _categoryLabel(loc),
                            ),
                            _MetaPill(
                              icon: Icons.payments_outlined,
                              text: _price.isEmpty ? '\$' : _price,
                            ),
                            _MetaPill(
                              icon: Icons.star,
                              text: _rating.toStringAsFixed(1),
                            ),
                            _MetaPill(
                              icon: Icons.place_outlined,
                              text: _distanceKm > 0
                                  ? '${_distanceKm.toStringAsFixed(1)} km'
                                  : '—',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),

                // TabBar pinned
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    backgroundColor: theme.scaffoldBackgroundColor,
                    tabBar: TabBar(
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor:
                      theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      tabs: [
                        const Tab(text: 'Informations'),
                        Tab(text: 'Avis (${_reviewCount == 0
                            ? 0
                            : _reviewCount})'),
                        const Tab(text: 'Communauté'),
                      ],
                    ),
                  ),
                ),
              ];
            },

            // Chaque tab = une ListView scrollable indépendante
            body: TabBarView(
              children: [
                // TAB 1
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    _SectionTitle(title: 'À propos'),
                    const SizedBox(height: 8),
                    Text(
                      _desc.isEmpty ? 'Aucune description.' : _desc,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
                    ),
                    const SizedBox(height: 18),

                    if (_amenities.isNotEmpty) ...[
                      _SectionTitle(title: 'Équipements'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _amenities
                            .map((e) => _ChipPill(text: e))
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                    ],

                    if ((_schedule ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      _SectionTitle(title: 'Horaires'),
                      const SizedBox(height: 8),
                      _InfoRow(icon: Icons.schedule, text: _schedule!.trim()),
                      const SizedBox(height: 18),
                    ],

                    _SectionTitle(title: 'Informations'),
                    const SizedBox(height: 10),

                    if ((_address ?? '')
                        .trim()
                        .isNotEmpty)
                      _InfoRow(
                          icon: Icons.location_on_outlined, text: _address!),

                    if ((_phone ?? '')
                        .trim()
                        .isNotEmpty)
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        text: _phone!,
                        onTap: () => _callPhone(),
                      ),

                    if ((_email ?? '')
                        .trim()
                        .isNotEmpty)
                      _InfoRow(
                        icon: Icons.mail_outline,
                        text: _email!,
                        onTap: () => _sendEmail(),
                      ),

                    if ((_website ?? '')
                        .trim()
                        .isNotEmpty)
                      _InfoRow(
                        icon: Icons.public,
                        text: _website!,
                        onTap: () => _openExternalLink(context, _website),
                      ),

                    const SizedBox(height: 18),

                    _SectionTitle(title: 'Réseaux sociaux'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _SocialCircle(
                          label: 'Facebook',
                          icon: Icons.facebook,
                          enabled: !((_facebookUrl ?? '')
                              .trim()
                              .isEmpty),
                          onTap: () => _openExternalLink(context, _facebookUrl),
                        ),
                        const SizedBox(width: 12),
                        _SocialCircle(
                          label: 'Instagram',
                          icon: Icons.camera_alt,
                          enabled: !((_instagramUrl ?? '')
                              .trim()
                              .isEmpty),
                          onTap: () =>
                              _openExternalLink(context, _instagramUrl),
                        ),
                        const SizedBox(width: 12),
                        _SocialCircle(
                          label: 'TikTok',
                          icon: Icons.music_note,
                          enabled: !((_tiktokUrl ?? '')
                              .trim()
                              .isEmpty),
                          onTap: () => _openExternalLink(context, _tiktokUrl),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    if (similar.isNotEmpty) ...[
                      _SectionTitle(title: 'Vous pourriez aussi aimer'),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 150,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: similar.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final item = similar[index];
                            return _SimilarCard(
                              place: item,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DetailScreen(
                                          place: item,
                                          category: category,
                                        ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),

                // TAB 2
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: const [
                    _EmptyBox(
                      text: 'Aucun avis synchronisé pour le moment.\n(Branche Firestore plus tard.)',
                    ),
                  ],
                ),

                //TAB 3
                ListView(
                  // padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  // children: const [
                  //   _EmptyBox(
                  //     text: 'Communauté indisponible pour le moment.\n(Prochaine itération.)',
                  //   ),
                  //],
                ),
              ],
            ),
          ),
        ),

        bottomNavigationBar: _BottomActionBar(
          primaryLabel: _isEvent ? 'Acheter un billet' : 'Réserver / Contacter',
          onPrimary: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isEvent
                      ? 'Action: acheter un billet (à connecter).'
                      : 'Action: réservation/contact (à connecter).',
                ),
              ),
            );
          },
          onSecondary: _openMaps,
        ),
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// UI Components
// -----------------------------------------------------------------------------

class DetailHeader extends StatelessWidget {
  final List<dynamic> photos;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onFavorite;
  final bool isFavorite;
  final VoidCallback onShare;
  final VoidCallback onViewAllPhotos;

  const DetailHeader({
    super.key,
    required this.photos,
    required this.title,
    required this.onBack,
    required this.onFavorite,
    required this.isFavorite,
    required this.onShare,
    required this.onViewAllPhotos,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhotos = photos.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasPhotos)
          PageView.builder(
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final p = photos[index].toString();
              return p.startsWith('assets/')
                  ? Image.asset(p, fit: BoxFit.cover)
                  : Image.network(p, fit: BoxFit.cover);
            },
          )
        else
          Container(color: theme.cardColor),

        // gradient bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.0),
                  Colors.black.withOpacity(0.55),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // top actions
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: Row(
            children: [
              _GlassIconButton(icon: Icons.arrow_back, onTap: onBack),
              const Spacer(),
              _GlassIconButton(
                icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                onTap: onFavorite,
                iconColor: isFavorite ? Constants.kinGold : null,
              ),
              const SizedBox(width: 10),
              _GlassIconButton(icon: Icons.share, onTap: onShare),
            ],
          ),
        ),

        // view all photos
        Positioned(
          right: 14,
          bottom: 16,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.cardColor.withOpacity(0.92),
              foregroundColor: theme.textTheme.bodyMedium?.color,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: onViewAllPhotos,
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('Voir toutes les photos'),
          ),
        ),

        // title
        Positioned(
          left: 16,
          bottom: 16,
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(
                  blurRadius: 10,
                  color: Colors.black.withOpacity(0.35),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.cardColor.withOpacity(0.65),
              border: Border.all(color: theme.dividerColor.withOpacity(0.25)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, color: iconColor ?? theme.iconTheme.color, size: 20),
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _ChipPill extends StatelessWidget {
  final String text;
  const _ChipPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: theme.textTheme.bodyLarge?.copyWith(height: 1.25)),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: onTap == null
          ? row
          : InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: row,
        ),
      ),
    );
  }
}

class _SocialCircle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _SocialCircle({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.cardColor,
            shape: BoxShape.circle,
            border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
          ),
          child: Icon(icon, size: 22, color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}

class _SimilarCard extends StatelessWidget {
  final dynamic place;
  final VoidCallback onTap;

  const _SimilarCard({required this.place, required this.onTap});

  T? _tryGet<T>(T Function() getter) {
    try {
      return getter();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final name = _tryGet(() => place.nom.toString()) ?? '—';
    final rating = _tryGet(() => (place.rating as double)) ?? 0.0;
    final photos = _tryGet(() => (place.photos as List))?.toList() ?? const [];
    final thumb = photos.isNotEmpty ? photos.first.toString() : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 190,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(0, 8),
              color: Colors.black.withOpacity(0.06),
            ),
          ],
          border: Border.all(color: theme.dividerColor.withOpacity(0.25)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb.isNotEmpty)
                      thumb.startsWith('assets/')
                          ? Image.asset(thumb, fit: BoxFit.cover)
                          : Image.network(thumb, fit: BoxFit.cover)
                    else
                      Container(color: theme.dividerColor.withOpacity(0.08)),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.0),
                              Colors.black.withOpacity(0.55),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Row(
                  children: const [
                    Icon(Icons.star, size: 16, color: Color(0xFFD2A100)),
                    SizedBox(width: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _BottomActionBar({
    required this.primaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.35))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
                ),
                onPressed: onSecondary,
                child: Icon(Icons.near_me_outlined, color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: onPrimary,
                  icon: const Icon(Icons.confirmation_number_outlined, size: 20),
                  label: Text(
                    primaryLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String text;
  const _EmptyBox({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: Text(text, style: theme.textTheme.bodyLarge?.copyWith(height: 1.35)),
    );
  }
}

class PhotoGalleryScreen extends StatelessWidget {
  final List<dynamic> photos;
  const PhotoGalleryScreen({Key? key, required this.photos}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Photos'),
      ),
      body: photos.isEmpty
          ? const Center(
        child: Text('Aucune photo', style: TextStyle(color: Colors.white)),
      )
          : PageView.builder(
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final p = photos[index].toString();
          return InteractiveViewer(
            child: Center(
              child: p.startsWith('assets/')
                  ? Image.asset(p, fit: BoxFit.contain)
                  : Image.network(p, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate({
    required this.tabBar,
    required this.backgroundColor,
  });

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
