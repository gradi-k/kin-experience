import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../utils/constants.dart';
import '../../localization/app_localizations.dart';
import '../../views/widgets/place_card.dart';

/// ✅ CORRIGÉ : Marges réduites sur grands écrans
class FeaturedCarousel extends StatefulWidget {
  final List<dynamic> featuredPlaces;
  final Function(dynamic) onTap;
  final bool autoPlay;
  final Duration autoPlayInterval;
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
  double _viewportFraction = 0.95;
  double _lastWidth = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncControllerToScreen();
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
    if (!mounted) return;
    _syncControllerToScreen();
  }

  void _syncControllerToScreen() {
    if (!mounted) return;

    final w = MediaQuery.sizeOf(context).width;

    if ((w - _lastWidth).abs() < 1) return;
    _lastWidth = w;

    final newFraction = _computeViewportFraction(w);

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
      setState(() {});
    }
  }

  double _computeViewportFraction(double width) {
    // ✅ Ajusté pour mieux utiliser l'espace sur grands écrans
    if (width >= 1100) return 0.60;  // Grande tablette
    if (width >= 800) return 0.68;   // Tablette
    if (width >= 600) return 0.82;   // Petit tablet
    return 0.95;                     // Phone
  }

  double _computeHeight(double width) {
    if (width >= 1100) return 340;
    if (width >= 800) return 320;
    if (width >= 600) return 290;
    return 250;
  }

  // ✅ Padding items réduit sur grands écrans
  EdgeInsets _computeItemPadding(int index, int total, double width) {
    // Sur grands écrans : marges équilibrées et réduites
    if (width >= 900) {
      return EdgeInsets.only(
        left: index == 0 ? 0 : 2,      // ✅ Réduit
        right: index == total - 1 ? 0 : 8,  // ✅ Réduit
      );
    }

    // Écrans moyens/petits
    return EdgeInsets.only(
      left: index == 0 ? 0 : 4,
      right: index == total - 1 ? 0 : 8,
    );
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
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
                  padding: _computeItemPadding(index, widget.featuredPlaces.length, width),  // ✅ Nouveau
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
        const SizedBox(height: 8),
      ],
    );
  }
}