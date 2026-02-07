// lib/views/widgets/place_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/constants.dart';

/// Widget réutilisable pour afficher un lieu (site, restaurant, hôtel, etc.).
class PlaceCard extends StatefulWidget {
  final dynamic place;
  final VoidCallback? onTap;

  const PlaceCard({
    super.key,
    required this.place,
    this.onTap,
  });

  @override
  State<PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<PlaceCard> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (!_isPressed) setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (_isPressed) setState(() => _isPressed = false);
  }

  // ✅ Helper sécurisé pour récupérer une valeur
  T? _tryGet<T>(dynamic obj, T? Function() getter) {
    try {
      return getter();
    } catch (_) {
      return null;
    }
  }

  // ✅ Récupère la première image de façon sécurisée
  // Gère le cas où photos est une String OU une List
  String? _getFirstPhoto(dynamic place) {
    try {
      final photos = place.photos;

      // Si photos est une String directe
      if (photos is String) {
        return photos.isNotEmpty ? photos : null;
      }

      // Si photos est une List
      if (photos is List && photos.isNotEmpty) {
        final first = photos.first;
        if (first is String && first.isNotEmpty) {
          return first;
        }
        return first?.toString();
      }

      return null;
    } catch (_) {
      // Essayer d'autres propriétés
      return _tryGet(place, () => place.image?.toString()) ??
          _tryGet(place, () => place.imageUrl?.toString()) ??
          _tryGet(place, () => place.photo?.toString()) ??
          _tryGet(place, () => place.cover?.toString());
    }
  }

  // ✅ Récupère le nom de façon sécurisée
  String _getName(dynamic place) {
    return _tryGet(place, () => place.nom?.toString())?.trim() ??
        _tryGet(place, () => place.name?.toString())?.trim() ??
        'Sans nom';
  }

  // ✅ Récupère le rating de façon sécurisée
  double _getRating(dynamic place) {
    try {
      final rating = place.rating;
      if (rating is double) return rating;
      if (rating is int) return rating.toDouble();
      if (rating is num) return rating.toDouble();
      return 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  // ✅ Récupère le prix de façon sécurisée
  String _getPrixRange(dynamic place) {
    return _tryGet(place, () => place.prixRange?.toString())?.trim() ??
        _tryGet(place, () => place.priceRange?.toString())?.trim() ??
        '';
  }

  // ✅ Vérifie isFeatured de façon sécurisée
  bool _isFeatured(dynamic place) {
    try {
      return place.isFeatured == true;
    } catch (_) {
      return false;
    }
  }

  bool _isTabletLike(BuildContext context) {
    final mq = MediaQuery.of(context);
    final shortest = mq.size.shortestSide;
    return shortest >= 600; // seuil tablette standard
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = widget.place;

    final photoUrl = _getFirstPhoto(place);
    final name = _getName(place);
    final rating = _getRating(place);
    final prixRange = _getPrixRange(place);
    final isFeatured = _isFeatured(place);

    final isTablet = _isTabletLike(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        // ✅ Hauteur adaptative : basée sur la largeur disponible
        // - téléphone (cards larges en liste) : ~300
        // - tablette / grille : un peu plus haut mais borné
        final double targetH = (w * 0.72).clamp(240.0, isTablet ? 380.0 : 320.0);

        // ✅ Spacings adaptatifs (mêmes proportions, juste mieux sur grands écrans)
        final double pad = isTablet ? 14.0 : 12.0;
        final double badgePadH = isTablet ? 10.0 : 8.0;
        final double badgePadV = isTablet ? 5.0 : 4.0;
        final double starSize = isTablet ? 18.0 : 16.0;

        return GestureDetector(
          onTap: widget.onTap,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: AnimatedScale(
            // ✅ Toujours une valeur finie -> pas de matrice invalide
            scale: _isPressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: theme.cardTheme.elevation,
              shadowColor: theme.cardTheme.shadowColor,
              child: Stack(
                children: [
                  // Image principale (hauteur responsive)
                  SizedBox(
                    height: targetH,
                    width: double.infinity,
                    child: _buildImage(photoUrl, theme),
                  ),

                  // Dégradé pour la lisibilité du texte
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color.fromARGB(37, 0, 0, 0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Badge « Mis en avant »
                  if (isFeatured)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: badgePadH,
                          vertical: badgePadV,
                        ),
                        decoration: BoxDecoration(
                          color: Constants.myOrange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Incontournable',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  // Texte en bas de carte
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: starSize,
                                color: Colors.yellow.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              if (prixRange.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    prixRange,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImage(String? photoUrl, ThemeData theme) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return _imageFallback(theme);
    }

    final isAsset = photoUrl.startsWith('assets/');
    final isNetwork =
        photoUrl.startsWith('http://') || photoUrl.startsWith('https://');

    if (isAsset) {
      return Image.asset(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imageFallback(theme),
      );
    }

    if (isNetwork) {
      // ✅ Cached network image (cache + placeholder + error)
      return CachedNetworkImage(
        imageUrl: photoUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorWidget: (context, url, error) => _imageFallback(theme),
      );
    }

    return _imageFallback(theme);
  }

  Widget _imageFallback(ThemeData theme) {
    return Container(
      color: Colors.grey.shade300,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 48,
        color: Colors.grey.shade500,
      ),
    );
  }
}
