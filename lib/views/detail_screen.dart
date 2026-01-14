// lib/views/detail_screen.dart
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/favorites_controller.dart';
import '../data/fake_data.dart';
import '../localization/app_localizations.dart';
import '../models/place_enums.dart';

class DetailScreen extends ConsumerWidget {
  final dynamic place;
  final PlaceCategory category;

  const DetailScreen({
    Key? key,
    required this.place,
    required this.category,
  }) : super(key: key);

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
  double get _rating => _tryGet(() => (place.rating as double)) ?? 0.0;
  String get _price => _tryGet(() => place.prixRange.toString()) ?? '—';

  double? get _lat => _tryGet(() => (place.latitude as double));
  double? get _lng => _tryGet(() => (place.longitude as double));

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
      _tryGet(() => (place.amenities as List).cast<String>()) ?? const <String>[];

  String? get _schedule => _tryGet<String?>(() => place.schedule as String?);

  int get _reviewCount => _tryGet(() => place.reviewCount as int) ?? 0;
  double get _distanceKm => _tryGet(() => place.distanceKm as double) ?? 0.0;

  bool get _isEvent => category == PlaceCategory.event;

  Color _gold(BuildContext context) => const Color(0xFFD2A100);

  // ---------------------------
  // Actions externes
  // ---------------------------

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/message/GNQGXDHSZ62SD1');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir WhatsApp.")),
      );
    }
  }

  Future<void> _openMaps(BuildContext context) async {
    final lat = _lat;
    final lng = _lng;

    if (lat != null && lng != null) {
      final appUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
      final webUri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng');

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

  Future<void> _callPhone(BuildContext context) async {
    final phone = (_phone ?? '').trim();
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'appeler ce numéro.")),
      );
    }
  }

  Future<void> _sendEmail(BuildContext context) async {
    final email = (_email ?? '').trim();
    if (email.isEmpty) return;
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir l'email.")),
      );
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
        source = fakeShoppings;
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
                // =========================================================
                // ✅ BARRE ACTIONS HORS IMAGE
                // =========================================================
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
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Partager (à connecter).')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // =========================================================
                // ✅ SLIVERAPPBAR = IMAGE ONLY
                // =========================================================
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
                                  builder: (_) => PhotoGalleryScreen(photos: _photos),
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

                // Bloc Titre + meta
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
                        Tab(text: 'Avis (${_reviewCount == 0 ? 0 : _reviewCount})'),
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    const _SectionTitle(title: 'À propos'),
                    const SizedBox(height: 8),
                    Text(
                      _desc.isEmpty ? 'Aucune description.' : _desc,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
                    ),
                    const SizedBox(height: 18),

                    if (_amenities.isNotEmpty) ...[
                      const _SectionTitle(title: 'Équipements'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _amenities.map((e) => _ChipPill(text: e)).toList(),
                      ),
                      const SizedBox(height: 18),
                    ],

                    if ((_schedule ?? '').trim().isNotEmpty) ...[
                      const _SectionTitle(title: 'Horaires'),
                      const SizedBox(height: 8),
                      _InfoRow(icon: Icons.schedule, text: _schedule!.trim()),
                      const SizedBox(height: 18),
                    ],

                    const _SectionTitle(title: 'Informations'),
                    const SizedBox(height: 10),

                    if ((_address ?? '').trim().isNotEmpty)
                      _InfoRow(icon: Icons.location_on_outlined, text: _address!),

                    if ((_phone ?? '').trim().isNotEmpty)
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        text: _phone!,
                        onTap: () => _callPhone(context),
                      ),

                    if ((_email ?? '').trim().isNotEmpty)
                      _InfoRow(
                        icon: Icons.mail_outline,
                        text: _email!,
                        onTap: () => _sendEmail(context),
                      ),

                    if ((_website ?? '').trim().isNotEmpty)
                      _InfoRow(
                        icon: Icons.public,
                        text: _website!,
                        onTap: () => _openExternalLink(context, _website),
                      ),

                    const SizedBox(height: 18),

                    const _SectionTitle(title: 'Réseaux sociaux'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _SocialCircle(
                          label: 'Facebook',
                          icon: Icons.facebook,
                          enabled: !((_facebookUrl ?? '').trim().isEmpty),
                          onTap: () => _openExternalLink(context, _facebookUrl),
                        ),
                        const SizedBox(width: 12),
                        _SocialCircle(
                          label: 'Instagram',
                          icon: Icons.camera_alt,
                          enabled: !((_instagramUrl ?? '').trim().isEmpty),
                          onTap: () => _openExternalLink(context, _instagramUrl),
                        ),
                        const SizedBox(width: 12),
                        _SocialCircle(
                          label: 'TikTok',
                          icon: Icons.music_note,
                          enabled: !((_tiktokUrl ?? '').trim().isEmpty),
                          onTap: () => _openExternalLink(context, _tiktokUrl),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    if (similar.isNotEmpty) ...[
                      const _SectionTitle(title: 'Vous pourriez aussi aimer'),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 150,
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

                // TAB 2 (✅ Avis Firestore + Ajout)
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: const [
                    _EmptyBox(text: 'Disponible Bientôt.'),
                  ],
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _BottomActionBar(
          primaryLabel: _isEvent ? 'Acheter un billet' : 'Réserver / Contacter',
          onPrimary: () {
            if (_isEvent) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Action: acheter un billet (à connecter).'),
                ),
              );
              return;
            }
            _openWhatsApp(context);
          },
          onSecondary: () => _openMaps(context),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// REVIEWS (Firestore) + Add review sheet (évite controller disposed + overflow)
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
                      const SnackBar(content: Text("Avis ajouté.")),
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
                    const SnackBar(content: Text("Connectez-vous pour laisser un avis.")),
                  );
                },
                child: const Text("Se connecter"),
              ),
          ],
        ),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection("reviews")
              .where("placeId", isEqualTo: placeId)
              .orderBy("createdAt", descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return _simpleBox("Erreur de chargement des avis.\n${snap.error}");
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return _simpleBox("Aucun avis pour le moment.");
            }

            return Column(
              children: docs.map((d) {
                final data = d.data();
                final authorName = (data["userName"] ?? "Utilisateur").toString();
                final comment = (data["comment"] ?? "").toString();
                final rating = (data["rating"] ?? 0).toString();

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authorName,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(Icons.star,
                              size: 18, color: Color(0xFFD2A100)),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      if (comment.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(comment),
                      ],
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
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

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
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
      await FirebaseFirestore.instance.collection("reviews").add({
        "placeId": widget.placeId,
        "placeName": widget.placeName,
        "category": widget.category,

        // IMPORTANT (rules): userId doit == request.auth.uid
        "userId": user.uid,
        "userEmail": user.email ?? "",
        "userName": (user.displayName ?? "Utilisateur").trim(),

        "rating": _rating,
        "comment": comment,

        "createdAt": FieldValue.serverTimestamp(),
        "createdAtClient": DateTime.now().millisecondsSinceEpoch,
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
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
// UI Components (inchangés)
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

  Color _gold() => const Color(0xFFD2A100);

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
            child: Icon(icon,
                color: iconColor ?? theme.iconTheme.color, size: 20),
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
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Row(
                  children: [
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
          border: Border(
            top: BorderSide(color: theme.dividerColor.withOpacity(0.35)),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
                ),
                onPressed: onSecondary,
                child: Icon(Icons.near_me_outlined,
                    color: theme.colorScheme.primary),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
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
