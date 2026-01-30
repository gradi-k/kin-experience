import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kin_experience/models/ad_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdsBannerCarousel extends StatefulWidget {
  final List<AdModel> ads;

  /// Autoplay on/off
  final bool autoPlay;

  /// Interval autoplay
  final Duration autoPlayInterval;

  /// Hauteur de la bannière (mobile baseline)
  final double height;

  const AdsBannerCarousel({
    super.key,
    required this.ads,
    this.autoPlay = true,
    this.autoPlayInterval = const Duration(seconds: 6),
    this.height = 150,
  });

  @override
  State<AdsBannerCarousel> createState() => _AdsBannerCarouselState();
}

class _AdsBannerCarouselState extends State<AdsBannerCarousel> {
  PageController? _controller;
  Timer? _timer;
  int _index = 0;

  double _lastViewportFraction = 0.92;

  List<AdModel> get _activeAds => widget.ads.where((e) => e.isActive).toList();

  @override
  void initState() {
    super.initState();
    _ensureController(viewportFraction: _lastViewportFraction, initialPage: 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoPlayIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant AdsBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si data/autoplay change, on relance proprement
    if (oldWidget.autoPlay != widget.autoPlay ||
        oldWidget.autoPlayInterval != widget.autoPlayInterval ||
        oldWidget.ads.length != widget.ads.length) {
      _startAutoPlayIfNeeded();
    }

    // ✅ Sécurité : si la liste a diminué
    final ads = _activeAds;
    if (_index >= ads.length && ads.isNotEmpty) {
      _index = ads.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _controller;
        if (!mounted || c == null || !c.hasClients) return;
        c.jumpToPage(_index);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _ensureController({
    required double viewportFraction,
    required int initialPage,
  }) {
    // Ne recrée pas si quasi identique
    if (_controller != null &&
        (viewportFraction - _lastViewportFraction).abs() < 0.01) {
      return;
    }

    _lastViewportFraction = viewportFraction;

    final old = _controller;
    _controller = PageController(
      viewportFraction: viewportFraction,
      initialPage: initialPage,
    );
    old?.dispose();
  }

  void _startAutoPlayIfNeeded() {
    _timer?.cancel();

    final ads = _activeAds;
    if (!widget.autoPlay || ads.length <= 1) return;

    _timer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted) return;

      final ads = _activeAds;
      final c = _controller;

      if (ads.isEmpty || c == null || !c.hasClients) return;

      final next = (_index + 1) % ads.length;
      c.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _openLink(BuildContext context, String? link) async {
    final value = (link ?? '').trim();
    if (value.isEmpty) return;

    final uri = Uri.tryParse(value);
    if (uri == null) return;

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir le lien.")),
      );
    }
  }

  // ✅ Responsive: combien de bannieres visibles (via viewportFraction)
  double _computeViewportFraction(double width) {
    // Téléphones / Fold fermé
    if (width < 600) return 0.92;

    // Fold ouvert / tablette portrait
    if (width < 900) return 0.72;

    // Tablette paysage / grand écran
    return 0.55; // ~2 visibles
  }

  // ✅ Responsive: hauteur (sans casser ton paramètre widget.height)
  double _computeHeight(double width) {
    // On part de ta height et on scale doucement
    if (width < 600) return widget.height;

    if (width < 900) {
      // +20% environ sur fold/tablette portrait
      return (widget.height * 1.2).clamp(widget.height, 220);
    }

    // +35% environ sur tablette paysage
    return (widget.height * 1.35).clamp(widget.height, 280);
  }

  EdgeInsets _computeItemPadding(int i, int len, double width) {
    // Sur grands écrans : padding plus équilibré
    final left = (i == 0) ? 16.0 : (width < 600 ? 0.0 : 8.0);
    final right = (i == len - 1) ? 16.0 : 12.0;
    return EdgeInsets.only(left: left, right: right);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ads = _activeAds;

    if (ads.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        final vf = _computeViewportFraction(width);
        final h = _computeHeight(width);

        // ✅ Important : adapter le controller quand largeur change (rotation/fold/split)
        _ensureController(viewportFraction: vf, initialPage: _index);

        return Column(
          children: [
            SizedBox(
              height: h,
              child: PageView.builder(
                controller: _controller,
                itemCount: ads.length,
                onPageChanged: (i) {
                  if (!mounted) return;
                  setState(() => _index = i);
                },
                itemBuilder: (context, i) {
                  final ad = ads[i];
                  final isAsset = ad.image.startsWith('assets/');

                  return Padding(
                    padding: _computeItemPadding(i, ads.length, width),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openLink(context, ad.link),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Image
                            isAsset
                                ? Image.asset(ad.image, fit: BoxFit.cover)
                                : CachedNetworkImage(
                              imageUrl: ad.image,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.image_not_supported_outlined,
                                size: 44,
                                color: Colors.white70,
                              ),
                            ),

                            // Overlay gradient
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withOpacity(0.05),
                                    Colors.black.withOpacity(0.55),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),

                            // CTA uniquement (tu avais déjà masqué title/subtitle)
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Spacer(),
                                  const SizedBox(height: 10),
                                  if ((ad.ctaLabel ?? '').trim().isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.18),
                                        borderRadius:
                                        BorderRadius.circular(999),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.35),
                                        ),
                                      ),
                                      child: Text(
                                        ad.ctaLabel,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
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
                },
              ),
            ),

            const SizedBox(height: 10),

            // Dots : Wrap (stable) + adapté aux grands écrans
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: List.generate(
                  ads.length,
                      (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: _index == i ? 16 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _index == i
                          ? theme.colorScheme.primary
                          : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
