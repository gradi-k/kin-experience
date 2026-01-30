import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../utils/constants.dart';
import '../../localization/app_localizations.dart';
import '../../views/widgets/place_card.dart';

/// Carrousel horizontal mettant en avant les lieux.
/// Responsive (tablettes / folds) + safe (pas de setState pendant build).
class FeaturedCarousel extends StatefulWidget {
  final List<dynamic> featuredPlaces;
  final Function(dynamic) onTap;

  /// Active le défilement automatique
  final bool autoPlay;

  /// Intervalle de défilement automatique
  final Duration autoPlayInterval;

  /// Durée d'animation lors du changement automatique
  final Duration autoPlayAnimationDuration;

  const FeaturedCarousel({
    super.key,
    required this.featuredPlaces,
    required this.onTap,
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 10),
    this.autoPlayAnimationDuration = const Duration(milliseconds: 450),
  });

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel>
    with WidgetsBindingObserver {
  PageController? _pageController;

  int _currentIndex = 0;
  Timer? _timer;

  // Pour éviter de recréer le controller en boucle
  double _viewportFraction = 0.95;
  double _lastWidth = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Controller sera créé dans didChangeDependencies (on a MediaQuery).
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncControllerToScreen(); // ✅ ici c'est safe (pas pendant build via LayoutBuilder)
    _maybeStartAutoPlay();
  }

  @override
  void didUpdateWidget(covariant FeaturedCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final listChanged =
        oldWidget.featuredPlaces.length != widget.featuredPlaces.length;
    final autoplayChanged = oldWidget.autoPlay != widget.autoPlay;
    final intervalChanged =
        oldWidget.autoPlayInterval != widget.autoPlayInterval;

    if (listChanged || autoplayChanged || intervalChanged) {
      _stopAutoPlay();

      // garde l’index dans la plage
      if (_currentIndex >= widget.featuredPlaces.length) {
        _currentIndex = 0;
        if (_pageController?.hasClients == true) {
          _pageController!.jumpToPage(0);
        }
      }

      _maybeStartAutoPlay();
    }
  }

  @override
  void didChangeMetrics() {
    // Orientation/resize (fold/unfold) → on resynchronise proprement.
    if (!mounted) return;
    _syncControllerToScreen();
  }

  void _syncControllerToScreen() {
    if (!mounted) return;

    final w = MediaQuery.sizeOf(context).width;

    // Anti-boucle: ne rien faire si width identique (petites variations ignorées)
    if ((w - _lastWidth).abs() < 1) return;
    _lastWidth = w;

    final newFraction = _computeViewportFraction(w);

    // Recrée le controller uniquement si la fraction change vraiment
    if (_pageController == null || (newFraction - _viewportFraction).abs() > 0.01) {
      final currentPage = _pageController?.hasClients == true
          ? (_pageController!.page?.round() ?? _currentIndex)
          : _currentIndex;

      _viewportFraction = newFraction;

      final old = _pageController;
      _pageController = PageController(
        viewportFraction: _viewportFraction,
        initialPage: currentPage.clamp(0, (widget.featuredPlaces.length - 1).clamp(0, 999999)),
      );

      old?.dispose();

      // 🔒 Pas de setState requis: le build lit _pageController, et didChangeDependencies
      // déclenche déjà un rebuild si nécessaire. Si tu veux forcer:
      setState(() {});
    }
  }

  double _computeViewportFraction(double width) {
    // Breakpoints pragmatiques pour tablettes / foldables
    // - Phone: carte presque pleine largeur
    // - Tablet portrait / Fold unfolded: plus de marge latérale
    // - Tablet landscape: preview plus large des voisins
    if (width >= 1100) return 0.55; // grande tablette / landscape
    if (width >= 800) return 0.62;  // tablette / fold unfolded
    if (width >= 600) return 0.78;  // petit tablet / grand phone
    return 0.95;                    // phone
  }

  double _computeHeight(double width) {
    // Hauteur légèrement plus généreuse sur grands écrans
    // + clamp pour éviter valeurs invalides.
    if (width >= 1100) return 340;
    if (width >= 800) return 320;
    if (width >= 600) return 290;
    return 250;
  }

  void _maybeStartAutoPlay() {
    if (!widget.autoPlay) return;
    if (widget.featuredPlaces.length <= 1) return;

    _timer?.cancel();
    _timer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted) return;
      final ctrl = _pageController;
      if (ctrl == null || !ctrl.hasClients) return;

      final count = widget.featuredPlaces.length;
      if (count <= 1) return;

      final next = (_currentIndex + 1) % count;

      // ✅ pas besoin de setState ici:
      // onPageChanged se chargera de mettre _currentIndex à jour.
      ctrl.animateToPage(
        next,
        duration: widget.autoPlayAnimationDuration,
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopAutoPlay() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoPlay();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    if (widget.featuredPlaces.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width;
    final height = _computeHeight(width).clamp(220.0, 420.0);

    final controller = _pageController ?? PageController(viewportFraction: 0.95);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre (tu l’avais commenté, je laisse commenté)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
          // child: Text(
          //   loc.translate('featured_title'),
          //   style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          // ),
        ),

        SizedBox(
          height: height,
          child: NotificationListener<UserScrollNotification>(
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
              controller: controller,
              itemCount: widget.featuredPlaces.length,
              onPageChanged: (index) {
                if (!mounted) return;
                setState(() => _currentIndex = index);
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
