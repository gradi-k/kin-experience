import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../utils/constants.dart';
import '../../localization/app_localizations.dart';
import '../../views/widgets/place_card.dart';

/// Carrousel horizontal mettant en avant les lieux.
/// Implémenté avec PageView (sans carousel_slider).
class FeaturedCarousel extends StatefulWidget {
  final List<dynamic> featuredPlaces;
  final Function(dynamic) onTap;

  /// ✅ Active le défilement automatique (désactivé par défaut)
  final bool autoPlay;

  /// ✅ Intervalle de défilement automatique
  final Duration autoPlayInterval;

  /// ✅ Durée d'animation lors du changement automatique
  final Duration autoPlayAnimationDuration;

  const FeaturedCarousel({
    Key? key,
    required this.featuredPlaces,
    required this.onTap,
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 10),
    this.autoPlayAnimationDuration = const Duration(milliseconds: 450),
  }) : super(key: key);

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.95);
  int _currentIndex = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // ✅ AutoPlay seulement si demandé et si plus d'un élément
    _maybeStartAutoPlay();
  }

  @override
  void didUpdateWidget(covariant FeaturedCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si paramètres changent ou liste change, on relance proprement
    final listChanged =
        oldWidget.featuredPlaces.length != widget.featuredPlaces.length;
    final autoplayChanged = oldWidget.autoPlay != widget.autoPlay;
    final intervalChanged =
        oldWidget.autoPlayInterval != widget.autoPlayInterval;

    if (listChanged || autoplayChanged || intervalChanged) {
      _stopAutoPlay();

      // On remet l'index dans la plage si la liste rétrécit
      if (_currentIndex >= widget.featuredPlaces.length) {
        _currentIndex = 0;
      }

      _maybeStartAutoPlay();
    }
  }

  void _maybeStartAutoPlay() {
    if (!widget.autoPlay) return;
    if (widget.featuredPlaces.length <= 1) return;

    _timer?.cancel();
    _timer = Timer.periodic(widget.autoPlayInterval, (_) async {
      if (!mounted) return;
      if (!_pageController.hasClients) return;
      final count = widget.featuredPlaces.length;
      if (count <= 1) return;

      final next = (_currentIndex + 1) % count;

      // ⚠️ évite setState après dispose
      _pageController.animateToPage(
        next,
        duration: widget.autoPlayAnimationDuration,
        curve: Curves.easeInOut,
      );

      // On met à jour l’index (pour les indicateurs)
      setState(() {
        _currentIndex = next;
      });
    });
  }

  void _stopAutoPlay() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopAutoPlay();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    // Sécurité si liste vide
    if (widget.featuredPlaces.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
          // child: Text(
          //   loc.translate('featured_title'),
          //   style: theme.textTheme.titleLarge?.copyWith(
          //     fontWeight: FontWeight.bold,
          //   ),
          // ),
        ),

        SizedBox(
          height: 250,
          child: NotificationListener<UserScrollNotification>(
            // ✅ Optionnel : si l’utilisateur swipe, on stop puis on relance après
            onNotification: (n) {
              if (!widget.autoPlay) return false;

              if (n.direction != ScrollDirection.idle) {
                _stopAutoPlay();
              } else {
                _maybeStartAutoPlay();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.featuredPlaces.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final place = widget.featuredPlaces[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: PlaceCard(
                    place: place,
                    onTap: () => widget.onTap(place),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Indicateurs
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.featuredPlaces.length,
                  (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentIndex == index ? 16 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentIndex == index
                      ? Constants.primaryColor
                      : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
