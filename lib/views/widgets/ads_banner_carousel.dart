import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kin_experience/models/ad_model.dart';
import 'package:url_launcher/url_launcher.dart';

class AdsBannerCarousel extends StatefulWidget {
  final List<AdModel> ads;

  /// Autoplay on/off
  final bool autoPlay;

  /// Interval autoplay
  final Duration autoPlayInterval;

  /// Hauteur de la bannière
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
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  List<AdModel> get _activeAds => widget.ads.where((e) => e.isActive).toList();

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);

    // Autoplay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoPlayIfNeeded();
    });
  }

  void _startAutoPlayIfNeeded() {
    _timer?.cancel();

    final ads = _activeAds;
    if (!widget.autoPlay || ads.length <= 1) return;

    _timer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted) return;
      final ads = _activeAds;
      if (ads.isEmpty) return;

      final next = (_index + 1) % ads.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
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
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ads = _activeAds;

    if (ads.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: ads.length,
            onPageChanged: (i) {
              setState(() => _index = i);
            },
            itemBuilder: (context, i) {
              final ad = ads[i];
              final isAsset = ad.image.startsWith('assets/');

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: ad.link == null ? null : () => _openLink(context, ad.link),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image
                        isAsset
                            ? Image.asset(ad.image, fit: BoxFit.cover)
                            : Image.network(ad.image, fit: BoxFit.cover),

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

                        // Text
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Spacer(),
                              // Text(
                              //   ad.title,
                              //   maxLines: 1,
                              //   overflow: TextOverflow.ellipsis,
                              //   style: theme.textTheme.titleMedium?.copyWith(
                              //     color: Colors.white,
                              //     fontWeight: FontWeight.w800,
                              //   ),
                              // ),
                              // const SizedBox(height: 4),
                              // Text(
                              //   ad.subtitle,
                              //   maxLines: 2,
                              //   overflow: TextOverflow.ellipsis,
                              //   style: theme.textTheme.bodySmall?.copyWith(
                              //     color: Colors.white.withOpacity(0.92),
                              //     height: 1.2,
                              //   ),
                              // ),
                              const SizedBox(height: 10),

                              if ((ad.ctaLabel ?? '').trim().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.35),
                                    ),
                                  ),
                                  child: Text(
                                    ad.ctaLabel!,
                                    style: theme.textTheme.labelLarge?.copyWith(
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

        // Dots sans overflow: Wrap (pas Row)
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
  }
}
