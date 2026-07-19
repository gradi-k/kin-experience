// lib/views/widgets/app_network_image.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Image réseau standard de l'app :
/// - cache disque + mémoire (CachedNetworkImage)
/// - décodage redimensionné via [memCacheWidth] (évite de décoder du 1920px
///   pour une vignette)
/// - placeholder shimmer au lieu d'un spinner
/// - fallback en cas d'URL vide / asset / erreur.
class AppNetworkImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;

  /// Largeur de décodage en pixels physiques. Null = pleine résolution
  /// (à réserver aux visionneuses plein écran).
  final int? memCacheWidth;
  final IconData fallbackIcon;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.fallbackIcon = Icons.image_not_supported_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = (url ?? '').trim();

    if (value.isEmpty) return _fallback(theme);

    if (value.startsWith('assets/')) {
      return Image.asset(
        value,
        fit: fit,
        cacheWidth: memCacheWidth,
        errorBuilder: (_, __, ___) => _fallback(theme),
      );
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: value,
        fit: fit,
        memCacheWidth: memCacheWidth,
        placeholder: (context, _) => AppImageShimmer(theme: theme),
        errorWidget: (context, _, __) => _fallback(theme),
      );
    }

    return _fallback(theme);
  }

  Widget _fallback(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        size: 32,
        color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
      ),
    );
  }
}

/// Placeholder shimmer réutilisable (images, skeletons de cartes/listes).
class AppImageShimmer extends StatelessWidget {
  final ThemeData theme;

  const AppImageShimmer({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(color: Colors.white),
    );
  }
}
