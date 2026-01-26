// lib/views/detail_screen.dart
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kin_experience/controllers/location_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/favorites_controller.dart';
import '../controllers/places_controller.dart';
import '../localization/app_localizations.dart';
import '../models/place_enums.dart';

class DetailScreen extends ConsumerWidget {
  final dynamic place;
  final PlaceCategory category;

  const DetailScreen({
    super.key,
    required this.place,
    required this.category,
  });

  // ---------------------------
  // Helpers "safe"
  // ---------------------------
  T? _tryGet<T>(T Function() getter) {
    try {
      return getter();
    } catch (_) {
      return null;
    }
  }

  String get _id => _tryGet(() => place.id.toString()) ?? '';
  String get _name => _tryGet(() => place.nom.toString()) ?? '—';
  String get _desc => _tryGet(() => place.description.toString()) ?? '';

  // ✅ Cast robuste (évite cast double strict)
  double get _ratingFallback {
    final v = _tryGet(() => place.rating);
    if (v is num) return v.toDouble();
    return 0.0;
  }

  String get _price => _tryGet(() => place.prixRange.toString()) ?? '—';

  double? get _lat => _tryGet<double?>(() => (place.latitude as num?)?.toDouble());
  double? get _lng => _tryGet<double?>(() => (place.longitude as num?)?.toDouble());

  List<dynamic> get _photos =>
      _tryGet(() => (place.photos as List))
          ?.where((p) => p.toString().trim().isNotEmpty)
          .toList() ?? const [];

  // Champs optionnels
  String? get _address => _tryGet<String?>(() => place.address as String?);
  String? get _phone => _tryGet<String?>(() => place.phone as String?);
  String? get _email => _tryGet<String?>(() => place.email as String?);
  String? get _website => _tryGet<String?>(() => place.website as String?);

  String? get _facebookUrl => _tryGet<String?>(() => place.facebookUrl as String?);
  String? get _instagramUrl => _tryGet<String?>(() => place.instagramUrl as String?);
  String? get _tiktokUrl => _tryGet<String?>(() => place.tiktokUrl as String?);

  List<String> get _amenities =>
      _tryGet(() => (place.amenities as List).cast<String>()) ?? const <String>[];

  String? get _schedule => _tryGet<String?>(() => place.schedule as String?);

  Color _gold(BuildContext context) => const Color(0xFFD2A100);

  // -----------------------------------------------------------
  // SHARE LINK
  // -----------------------------------------------------------
  String _buildShareLink() {
    final cat = category.name;
    final base = 'https://kincityguide.app/item';
    final uri = Uri.parse(base).replace(queryParameters: {
      'category': cat,
      'id': _id,
    });
    return uri.toString();
  }

  Future<void> _sharePlace(BuildContext context) async {
    final link = _buildShareLink();
    final text = 'Découvre "$_name" sur Kin Experience:\n$link';

    try {
      await Share.share(text);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lien copié dans le presse-papier.")),
        );
      }
    }
  }

  // -----------------------------------------------------------
  // Distance dynamique
  // -----------------------------------------------------------
  double _deg2rad(double deg) => deg * (pi / 180.0);

  double _haversineKm({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  String _formatDistanceKm({required AsyncValue<dynamic> posAsync}) {
    final plat = _lat;
    final plng = _lng;
    if (plat == null || plng == null) return '—';

    return posAsync.when(
      data: (pos) {
        final ulat = (pos.latitude as num?)?.toDouble();
        final ulng = (pos.longitude as num?)?.toDouble();
        if (ulat == null || ulng == null) return '—';
        final km = _haversineKm(lat1: ulat, lng1: ulng, lat2: plat, lng2: plng);
        return '${km.toStringAsFixed(1)} km';
      },
      loading: () => '…',
      error: (_, __) => '—',
    );
  }

  // -----------------------------------------------------------
  // Horaires -> Ouvert/Fermé
  // -----------------------------------------------------------
  bool? _isOpenNowFromSchedule(String scheduleRaw) {
    final s = scheduleRaw.trim();
    if (s.isEmpty) return null;

    final re = RegExp(r'(\d{1,2}):(\d{2})');
    final matches = re.allMatches(s).toList();
    if (matches.length < 2) return null;

    int toMinutes(RegExpMatch m) {
      final hh = int.parse(m.group(1)!);
      final mm = int.parse(m.group(2)!);
      return hh * 60 + mm;
    }

    final start = toMinutes(matches[0]);
    final end = toMinutes(matches[1]);

    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;

    if (end >= start) {
      return nowMin >= start && nowMin <= end;
    } else {
      return nowMin >= start || nowMin <= end;
    }
  }

  // -----------------------------------------------------------
  // Links
  // -----------------------------------------------------------
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

  // -----------------------------------------------------------
  // Maps
  // -----------------------------------------------------------
  Future<void> _openMaps(BuildContext context) async {
    final lat = _lat;
    final lng = _lng;

    if (lat != null && lng != null) {
      final appUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
      final webUri =
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

      if (await canLaunchUrl(appUri)) {
        final ok = await launchUrl(appUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }

      final okWeb = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (!okWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir Google Maps.")),
        );
      }
      return;
    }

    final address = (_address ?? '').trim();
    final query = address.isNotEmpty ? '$_name, $address' : _name;

    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );

    final ok = await launchUrl(webUri, mode: LaunchMode.externalApplication);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir Google Maps.")),
      );
    }
  }

  // -----------------------------------------------------------
  // CTA
  // -----------------------------------------------------------
  String _primaryCtaLabel() {
    switch (category) {
      case PlaceCategory.hotel:
        return "Réserver";
      case PlaceCategory.event:
        return "Acheter un billet ici";
      case PlaceCategory.site:
        return "Visiter";
      case PlaceCategory.resto:
        return "Réserver / Commander";
      case PlaceCategory.entreprise:
        return "Contacter l’entreprise";
      case PlaceCategory.shopping:
        return "Découvrir la boutique";
      default:
        return 'En savoir plus';
    }
  }

  IconData _primaryCtaIcon() {
    switch (category) {
      case PlaceCategory.hotel:
        return Icons.bed_outlined;
      case PlaceCategory.event:
        return Icons.confirmation_number_outlined;
      case PlaceCategory.site:
        return Icons.explore_outlined;
      case PlaceCategory.resto:
        return Icons.restaurant_outlined;
      case PlaceCategory.entreprise:
        return Icons.support_agent_outlined;
      case PlaceCategory.shopping:
        return Icons.shopping_bag_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  // -----------------------------------------------------------
  // Similar contents - loaded from Firebase provider
  // -----------------------------------------------------------

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
      default:
        return loc.translate('other');
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
      default:
        return Icons.place_outlined;
    }
  }

  // -----------------------------------------------------------
  // Firestore Reviews query
  // -----------------------------------------------------------
  Query<Map<String, dynamic>> _reviewsQuery() {
    return FirebaseFirestore.instance
        .collection("reviews")
        .where("placeId", isEqualTo: _id)
        .orderBy("createdAt", descending: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final posAsync = ref.watch(userPositionProvider);

    final favoritesState = ref.watch(favoritesControllerProvider);
    final favoritesNotifier = ref.read(favoritesControllerProvider.notifier);

    final isFav = favoritesState.maybeWhen(
      data: (list) => favoritesNotifier.isFavorite(place, category),
      orElse: () => false,
    );

    // ✅ Charger les lieux similaires depuis Firebase
    final similarAsync = ref.watch(placesByCategoryProvider(category));
    final similar = similarAsync.maybeWhen(
      data: (items) {
        final currentId = _tryGet(() => place.id.toString()) ?? '';
        return items
            .where((e) {
          final id = _tryGet(() => e.id.toString()) ?? '';
          return id != currentId;
        })
            .take(6)
            .toList();
      },
      orElse: () => <dynamic>[],
    );

    final scheduleRaw = (_schedule ?? '').trim();
    final openNow = scheduleRaw.isNotEmpty ? _isOpenNowFromSchedule(scheduleRaw) : null;
    final openLabel = openNow == null ? null : (openNow ? "Ouvert" : "Fermé");
    final openColor =
    openNow == null ? null : (openNow ? Colors.green : theme.colorScheme.error);

    final distanceText = _formatDistanceKm(posAsync: posAsync);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(
                      children: [
                        _TopIconButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _TopIconButton(
                          icon: isFav ? Icons.favorite : Icons.favorite_border,
                          iconColor: isFav ? _gold(context) : null,
                          onTap: () async {
                            await favoritesNotifier.toggleFavorite(place, category);
                          },
                        ),
                        const SizedBox(width: 10),
                        _TopIconButton(
                          icon: Icons.share,
                          onTap: () => _sharePlace(context),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverAppBar(
                  pinned: false,
                  expandedHeight: 260,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  elevation: 0,
                  automaticallyImplyLeading: false,
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
                        Positioned(
                          right: 14,
                          bottom: 18,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.cardColor.withOpacity(0.92),
                              foregroundColor: theme.textTheme.bodyMedium?.color,
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
                            icon: const Icon(Icons.photo_library_outlined, size: 18),
                            label: const Text('Voir toutes les photos'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

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
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _reviewsQuery().snapshots(),
                          builder: (context, snap) {
                            double avg = _ratingFallback;
                            int count = 0;

                            if (snap.hasData) {
                              final docs = snap.data!.docs;
                              count = docs.length;
                              if (count > 0) {
                                final sum = docs.fold<double>(0, (acc, d) {
                                  final r = (d.data()["rating"] ?? 0);
                                  return acc + (r is num ? r.toDouble() : 0.0);
                                });
                                avg = sum / count;
                              }
                            }

                            return Wrap(
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
                                  text: count > 0
                                      ? '${avg.toStringAsFixed(1)} ($count)'
                                      : avg.toStringAsFixed(1),
                                ),
                                _MetaPill(
                                  icon: Icons.place_outlined,
                                  text: distanceText,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        const Divider(thickness: 1,color: Colors.black26,),
                        //const SizedBox(height: 2),
                      ],
                    ),
                  ),
                ),

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
                        Tab(
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _reviewsQuery().snapshots(),
                            builder: (context, snap) {
                              final c = snap.hasData ? snap.data!.docs.length : 0;
                              return Text('Avis ($c)');
                            },
                          ),
                        ),
                        const Tab(text: 'Communauté'),

                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [

                // TAB 1
                ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom,),
                  children: [

                    const Divider(thickness: 1,color: Colors.black26,),
                    const SizedBox(height: 10),
                    const _SectionTitle(title: 'À propos'),
                    const SizedBox(height: 8),
                    Text(
                      _desc.isEmpty ? 'Aucune description.' : _desc,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
                    ),
                    const SizedBox(height: 18),

                    if (_amenities.isNotEmpty) ...[
                      const Divider(thickness: 1,color: Colors.black26,),
                      const SizedBox(height: 10),
                      const _SectionTitle(title: 'Équipements'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _amenities.map((e) => _ChipPill(text: e)).toList(),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const Divider(thickness: 1,color: Colors.black26,),
                    const SizedBox(height: 10),

                    if (scheduleRaw.isNotEmpty) ...[
                      const _SectionTitle(title: 'Horaires'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoRow(
                              icon: Icons.schedule,
                              text: scheduleRaw,
                            ),
                          ),
                          if (openLabel != null) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: (openColor ?? theme.dividerColor)
                                    .withOpacity(0.12),
                                border: Border.all(
                                  color: (openColor ?? theme.dividerColor)
                                      .withOpacity(0.35),
                                ),
                              ),
                              child: Text(
                                openLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: openColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    const Divider(thickness: 1,color: Colors.black26,),
                    const SizedBox(height: 10),
                    const _SectionTitle(title: 'Informations'),
                    const SizedBox(height: 10),

                    const SizedBox(height: 5),

                    if ((_address ?? '').trim().isNotEmpty)
                      _InfoRow(icon: Icons.location_on_outlined, text: _address!),

                    if ((_phone ?? '').trim().isNotEmpty)
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        text: _phone!,
                        onTap: () async {
                          final phone = (_phone ?? '').trim();
                          if (phone.isEmpty) return;
                          final uri = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                  Text("Impossible d'appeler ce numéro.")),
                            );
                          }
                        },
                      ),

                    if ((_email ?? '').trim().isNotEmpty)
                      _InfoRow(
                        icon: Icons.mail_outline,
                        text: _email!,
                        onTap: () async {
                          final email = (_email ?? '').trim();
                          if (email.isEmpty) return;
                          final uri = Uri.parse('mailto:$email');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Impossible d'ouvrir l'email.")),
                            );
                          }
                        },
                      ),

                    if ((_website ?? '').trim().isNotEmpty)
                      _InfoRow(
                        icon: Icons.public,
                        text: _website!,
                        onTap: () => _openExternalLink(context, _website),
                      ),

                    const SizedBox(height: 10),
                    const Divider(thickness: 1,color: Colors.black26,),
                    const SizedBox(height: 10),

                    const _SectionTitle(title: 'Réseaux sociaux'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _SocialCircle(
                          label: 'Facebook',
                          icon: FontAwesomeIcons.facebookF,
                          enabled: !((_facebookUrl ?? '').trim().isEmpty),
                          onTap: () => _openExternalLink(context, _facebookUrl),
                        ),
                        const SizedBox(width: 12),
                        _SocialCircle(
                          label: 'Instagram',
                          icon: FontAwesomeIcons.instagram,
                          enabled: !((_instagramUrl ?? '').trim().isEmpty),
                          onTap: () => _openExternalLink(context, _instagramUrl),
                        ),
                        const SizedBox(width: 12),
                        _SocialCircle(
                          label: 'TikTok',
                          icon: FontAwesomeIcons.tiktok,
                          enabled: !((_tiktokUrl ?? '').trim().isEmpty),
                          onTap: () => _openExternalLink(context, _tiktokUrl),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    const Divider(thickness: 1,color: Colors.black26,),

                    if (similar.isNotEmpty) ...[
                      const _SectionTitle(title: 'Vous pourriez aussi aimer'),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 180,
                        width: 320,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: similar.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final item = similar[index];
                            return _SimilarCard(
                              place: item,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DetailScreen(
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
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                  children: [
                    _ReviewsSection(
                      placeId: _id,
                      placeName: _name,
                      category: category.name,
                    ),
                  ],
                ),

                // TAB 3
                ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                  children: const [
                    _EmptyBox(text: 'Disponible Bientôt.'),
                  ],
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _BottomActionBar(
          primaryLabel: _primaryCtaLabel(),
          primaryIcon: _primaryCtaIcon(),
          onPrimary: () => _openExternalLink(context, _website),
          onSecondary: () => _openMaps(context),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// REVIEWS SECTION
// -----------------------------------------------------------------------------
class _ReviewsSection extends ConsumerWidget {
  final String placeId;
  final String placeName;
  final String category;

  const _ReviewsSection({
    required this.placeId,
    required this.placeName,
    required this.category,
  });

  Query<Map<String, dynamic>> _query() {
    return FirebaseFirestore.instance
        .collection("reviews")
        .where("placeId", isEqualTo: placeId)
        .orderBy("createdAt", descending: true)
        .limit(80);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Avis",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            if (user != null)
              ElevatedButton.icon(
                onPressed: () async {
                  final ok = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => _AddReviewSheet(
                      placeId: placeId,
                      placeName: placeName,
                      category: category,
                    ),
                  );

                  if (ok == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Avis envoyé.")),
                    );
                  }
                },
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: const Text("Ajouter"),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              )
            else
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Connectez-vous pour laisser un avis.")),
                  );
                },
                child: const Text("Se connecter"),
              ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _query().snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return _simpleBox("Erreur de chargement des avis.\n${snap.error}");
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs;

            double avg = 0.0;
            if (docs.isNotEmpty) {
              final sum = docs.fold<double>(0, (acc, d) {
                final r = d.data()["rating"];
                return acc + (r is num ? r.toDouble() : 0.0);
              });
              avg = sum / docs.length;
            }

            if (docs.isEmpty) {
              return Column(
                children: [
                  _ratingSummary(theme, avg: 0.0, count: 0),
                  const SizedBox(height: 10),
                  _simpleBox("Aucun avis pour le moment."),
                ],
              );
            }

            return Column(
              children: [
                _ratingSummary(theme, avg: avg, count: docs.length),
                const SizedBox(height: 10),
                ...docs.map((d) => _reviewCard(context, theme, user, d)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _ratingSummary(ThemeData theme, {required double avg, required int count}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: Color(0xFFD2A100)),
          const SizedBox(width: 8),
          Text(
            count == 0 ? "Aucune note" : "${avg.toStringAsFixed(1)} / 5",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "($count avis)",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(
      BuildContext context,
      ThemeData theme,
      User? currentUser,
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();
    final authorName = (data["userName"] ?? "Utilisateur").toString();
    final authorPhoto = (data["userPhotoUrl"] ?? "").toString().trim();

    final comment = (data["comment"] ?? "").toString().trim();
    final ratingNum = data["rating"];
    final rating = ratingNum is num ? ratingNum.toDouble() : 0.0;

    final userId = (data["userId"] ?? "").toString();
    final photoUrl = (data["photoUrl"] ?? "").toString().trim();

    final canDelete = currentUser != null && currentUser.uid == userId;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.50),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ✅ Avatar auteur (photo profil)
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.dividerColor.withOpacity(0.2),
                backgroundImage: authorPhoto.isNotEmpty ? NetworkImage(authorPhoto) : null,
                child: authorPhoto.isEmpty
                    ? const Icon(Icons.person_outline, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  authorName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StarsRow(value: rating),
              if (canDelete) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: "Supprimer",
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Supprimer l’avis ?"),
                        content: const Text("Cette action est définitive."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Annuler"),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Supprimer"),
                          ),
                        ],
                      ),
                    );

                    if (ok == true) {
                      await _deleteReview(context, docId: doc.id, photoUrl: photoUrl);
                    }
                  },
                  icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                ),
              ],
            ],
          ),

          if (photoUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: theme.dividerColor.withOpacity(0.08),
                    alignment: Alignment.center,
                    child: const Text("Image indisponible"),
                  ),
                ),
              ),
            ),
          ],

          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(comment, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Future<void> _deleteReview(BuildContext context,
      {required String docId, required String photoUrl}) async {
    try {
      await FirebaseFirestore.instance.collection("reviews").doc(docId).delete();

      if (photoUrl.trim().isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(photoUrl).delete();
        } catch (_) {}
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Avis supprimé.")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur suppression: $e")),
        );
      }
    }
  }

  Widget _simpleBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(text),
    );
  }
}

class _StarsRow extends StatelessWidget {
  final double value; // 0..5
  const _StarsRow({required this.value});

  @override
  Widget build(BuildContext context) {
    final full = value.floor().clamp(0, 5);
    final half = (value - full) >= 0.5 ? 1 : 0;
    final empty = 5 - full - half;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(full,
                (_) => const Icon(Icons.star, size: 18, color: Color(0xFFD2A100))),
        if (half == 1)
          const Icon(Icons.star_half, size: 18, color: Color(0xFFD2A100)),
        ...List.generate(
          empty,
              (_) => Icon(Icons.star_border,
              size: 18, color: Colors.grey.withOpacity(0.6)),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// ADD REVIEW SHEET
// -----------------------------------------------------------------------------
class _AddReviewSheet extends StatefulWidget {
  final String placeId;
  final String placeName;
  final String category;

  const _AddReviewSheet({
    required this.placeId,
    required this.placeName,
    required this.category,
  });

  @override
  State<_AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<_AddReviewSheet> {
  final _commentCtrl = TextEditingController();
  int _rating = 5;
  bool _saving = false;
  String? _error;

  File? _pickedImage;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    try {
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (xfile == null) return;

      setState(() {
        _pickedImage = File(xfile.path);
      });
    } catch (e) {
      setState(() => _error = "Impossible de sélectionner l'image: $e");
    }
  }

  Future<String?> _uploadReviewPhoto({
    required String placeId,
    required String userId,
    required File file,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = "review_$ts.jpg";

    final ref = FirebaseStorage.instance
        .ref()
        .child("review_photos/$placeId/$userId/$fileName");

    final metadata = SettableMetadata(contentType: "image/jpeg");

    final task = await ref.putFile(file, metadata);
    if (task.state != TaskState.success) return null;

    return await ref.getDownloadURL();
  }

  // ✅ récupère photo profil (Firestore users/{uid})
  Future<String> _getMyProfilePhotoUrl(User user) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = snap.data();
      final fromFs = (data?['photoUrl'] ?? data?['photoURL'] ?? '').toString().trim();
      if (fromFs.isNotEmpty) return fromFs;

      final fromAuth = (user.photoURL ?? '').toString().trim();
      return fromAuth;
    } catch (_) {
      final fromAuth = (user.photoURL ?? '').toString().trim();
      return fromAuth;
    }
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = "Vous devez être connecté.");
      return;
    }

    final comment = _commentCtrl.text.trim();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // ✅ 1) upload photo avis si présente (optionnel)
      String? photoUrl;
      if (_pickedImage != null) {
        final uploaded = await _uploadReviewPhoto(
          placeId: widget.placeId,
          userId: user.uid,
          file: _pickedImage!,
        );
        if (uploaded == null) {
          throw Exception("Upload photo échoué.");
        }
        photoUrl = uploaded;
      }

      // ✅ 3) write Firestore (anti-permission denied)
      // IMPORTANT (Option 1): on n'envoie PAS les champs optionnels s'ils sont vides.
      // Ça évite de "casser" les rules qui valident le schéma.
      final payload = <String, dynamic>{
        "placeId": widget.placeId,
        "placeName": widget.placeName,
        "category": widget.category,
        "userId": user.uid,
        "userEmail": (user.email ?? "").trim(),
        "userName": (user.displayName ?? "Utilisateur").trim(),
        "rating": _rating,
        "createdAt": FieldValue.serverTimestamp(),
        "createdAtClient": DateTime.now().millisecondsSinceEpoch,
      };

      if (comment.isNotEmpty) {
        payload["comment"] = comment;
      }

      if ((photoUrl ?? "").trim().isNotEmpty) {
        payload["photoUrl"] = photoUrl;
      }

      await FirebaseFirestore.instance.collection("reviews").add(payload);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseException catch (e) {
      // ✅ Message clair permission-denied
      if (e.code == 'permission-denied') {
        setState(() => _error =
        "Permission refusée (Firestore rules). Vérifie que la règle /reviews autorise create et que userId == auth.uid.");
      } else {
        setState(() => _error = "Erreur Firebase: ${e.code} - ${e.message}");
      }
    } catch (e) {
      setState(() => _error = "Erreur: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ajouter un avis",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              "Note",
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),

            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                final active = star <= _rating;
                return IconButton(
                  onPressed: _saving ? null : () => setState(() => _rating = star),
                  icon: Icon(active ? Icons.star : Icons.star_border),
                  color: active ? const Color(0xFFD2A100) : theme.dividerColor,
                );
              }),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickImage,
                  icon: const Icon(Icons.photo_camera_back_outlined, size: 18),
                  label: const Text("Ajouter photo"),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(width: 12),
                if (_pickedImage != null)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _pickedImage!,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            TextField(
              controller: _commentCtrl,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: "Commentaire (optionnel)",
                filled: true,
                fillColor: theme.brightness == Brightness.light
                    ? Colors.grey.shade100
                    : Colors.grey.shade800,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  "Publier",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// UI Components
// -----------------------------------------------------------------------------
class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: iconColor ?? theme.iconTheme.color,
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
        //border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
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
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.25),
          ),
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
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
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
    final rating = _tryGet(() => place.rating.toString()) ?? '4.5';
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
          border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
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
                          ? Image.asset(thumb, fit: BoxFit.cover, cacheWidth: 400)
                          : Image.network(thumb, fit: BoxFit.cover, cacheWidth: 400)
                    else
                      Container(color: theme.dividerColor.withOpacity(0.08)),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Color(0xFFD2A100)),
                    const SizedBox(width: 6),
                    Text(
                      rating,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
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
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _BottomActionBar({
    required this.primaryLabel,
    required this.primaryIcon,
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
          border: Border(
            top: BorderSide(color: theme.dividerColor.withOpacity(0.35)),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
                ),
                onPressed: onSecondary,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "S'y rendre",
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: onPrimary,
                  icon: Icon(primaryIcon, size: 20),
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
  const PhotoGalleryScreen({super.key, required this.photos});

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
    return oldDelegate.tabBar != tabBar || oldDelegate.backgroundColor != backgroundColor;
  }
}