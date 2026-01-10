import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/places_controller.dart';
import '../controllers/favorites_controller.dart';
import '../localization/app_localizations.dart';
import '../utils/constants.dart';

import '../data/fake_data.dart';
import 'widgets/place_card.dart';

/// Écran affichant le détail d’un lieu (site, restaurant, hôtel, etc.).
/// - Carrousel principal d'images (PageView)
/// - Galerie d'images en une ligne (scroll horizontal) + sélection
/// - Infos + actions + réseaux sociaux
/// - Contenus similaires (même catégorie) juste en dessous
class DetailScreen extends ConsumerStatefulWidget {
  final dynamic place;
  final PlaceCategory category;

  const DetailScreen({
    Key? key,
    required this.place,
    required this.category,
  }) : super(key: key);

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  late final PageController _pageController;
  int _activeImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openMaps() async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${widget.place.latitude},${widget.place.longitude}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildPhoto(String photo, {BoxFit fit = BoxFit.cover}) {
    final isAsset = photo.toString().startsWith('assets/');
    return isAsset
        ? Image.asset(photo, fit: fit)
        : Image.network(photo, fit: fit);
  }

  List<dynamic> _similarItems() {
    // Récupère la bonne liste selon la catégorie
    List<dynamic> source;
    switch (widget.category) {
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
      default:
        source = fakeEntreprises;
        break;
    }

    // Filtre: exclure l’élément actuel
    final currentId = widget.place.id?.toString();
    final list = source.where((e) => e.id?.toString() != currentId).toList();

    // Optionnel : trier par rating décroissant
    list.sort((a, b) => (b.rating as num).compareTo(a.rating as num));

    // Limiter
    return list.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // ✅ Lire l’état favorites via provider pour rebuild automatique
    final favoritesAsync = ref.watch(favoritesControllerProvider);
    final favoritesNotifier = ref.read(favoritesControllerProvider.notifier);

    final isFav = favoritesAsync.maybeWhen(
      data: (_) => favoritesNotifier.isFavorite(widget.place, widget.category),
      orElse: () => favoritesNotifier.isFavorite(widget.place, widget.category),
    );

    final photos = (widget.place.photos as List?)?.cast<dynamic>() ?? [];
    final similar = _similarItems();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.place.nom),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Constants.primaryColor : null,
            ),
            onPressed: () async {
              await favoritesNotifier.toggleFavorite(widget.place, widget.category);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // =========================
          // 1) CARROUSEL PRINCIPAL
          // =========================
          if (photos.isNotEmpty)
            SizedBox(
              height: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: photos.length,
                  onPageChanged: (i) => setState(() => _activeImageIndex = i),
                  itemBuilder: (context, index) {
                    final photo = photos[index].toString();
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildPhoto(photo, fit: BoxFit.cover),
                        // léger gradient en bas pour lisibilité
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.center,
                              colors: [
                                Colors.black.withOpacity(0.45),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

          const SizedBox(height: 12),

          // =========================
          // 2) GALERIE 1 LIGNE (scroll horizontal)
          // =========================
          if (photos.length > 1)
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final photo = photos[index].toString();
                  final isActive = index == _activeImageIndex;

                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                      );
                      setState(() => _activeImageIndex = index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 78,
                      height: 78,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isActive
                              ? Constants.accentColor
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildPhoto(photo, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),

          // =========================
          // 3) INFOS
          // =========================
          Text(
            widget.place.nom,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.star, color: Colors.yellow.shade600, size: 20),
              const SizedBox(width: 4),
              Text(
                (widget.place.rating as num).toStringAsFixed(1),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 12),
              Text(
                widget.place.prixRange.toString(),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            widget.place.description.toString(),
            style: theme.textTheme.bodyLarge,
          ),

          const SizedBox(height: 24),

          // =========================
          // 4) ACTIONS : S’y rendre + Contact
          // =========================
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openMaps,
                  icon: const Icon(Icons.map),
                  label: const Text("S’y rendre"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: tu mettras ton action contact
                  },
                  icon: const Icon(Icons.phone),
                  label: const Text('Contact'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // =========================
          // 5) RESEAUX SOCIAUX
          // =========================
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.facebook),
                onPressed: () {
                  // TODO: lien facebook à ajouter dans les données
                },
              ),
              // IconButton(
              //   icon: const Icon(Icons.instagram),
              //   onPressed: () {
              //     // TODO: lien instagram à ajouter
              //   },
              // ),
              IconButton(
                icon: const Icon(Icons.tiktok),
                onPressed: () {
                  // TODO: lien tiktok à ajouter
                },
              ),
            ],
          ),

          const SizedBox(height: 18),

          // =========================
          // 6) CONTENUS SIMILAIRES
          // =========================
          if (similar.isNotEmpty) ...[
            Text(
              loc.translate('similar_content') == 'similar_content'
                  ? 'Ça pourrait vous intéresser '
                  : loc.translate('similar_content'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: similar.length,
                itemBuilder: (context, index) {
                  final item = similar[index];
                  return Container(
                    width: 220,
                    margin: EdgeInsets.only(
                      left: index == 0 ? 0 : 10,
                      right: index == similar.length - 1 ? 0 : 0,
                    ),
                    child: PlaceCard(
                      place: item,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DetailScreen(
                              place: item,
                              category: widget.category,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
