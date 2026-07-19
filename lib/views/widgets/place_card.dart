// lib/views/widgets/place_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../controllers/location_controller.dart';
import '../../utils/constants.dart';
import 'app_network_image.dart';

/// Widget réutilisable pour afficher un lieu (site, restaurant, hôtel, etc.).
class PlaceCard extends ConsumerStatefulWidget {
  final dynamic place;
  final VoidCallback? onTap;

  const PlaceCard({
    super.key,
    required this.place,
    this.onTap,
  });

  @override
  ConsumerState<PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends ConsumerState<PlaceCard> {
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

  double? _latOf(dynamic p) =>
      _tryGet<num>(p, () => (p.latitude as num))?.toDouble() ??
          _tryGet<num>(p, () => (p.lat as num))?.toDouble();

  double? _lngOf(dynamic p) =>
      _tryGet<num>(p, () => (p.longitude as num))?.toDouble() ??
          _tryGet<num>(p, () => (p.lng as num))?.toDouble() ??
          _tryGet<num>(p, () => (p.lon as num))?.toDouble();

  /// Badge « X km » si la position utilisateur et les coordonnées du lieu
  /// sont connues (réutilise le userPositionProvider déjà en cache).
  String? _distanceLabel(dynamic place) {
    final pos = ref.watch(userPositionProvider).whenOrNull(data: (p) => p);
    if (pos == null) return null;

    final lat = _latOf(place);
    final lng = _lngOf(place);
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;

    final meters =
        Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng);
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
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
    final distanceLabel = _distanceLabel(place);

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
                              if (distanceLabel != null) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.place_outlined,
                                  size: starSize - 2,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  distanceLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
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
    // Décodage plafonné à 800px : suffisant pour une carte, évite de
    // décharger en mémoire des photos Storage jusqu'à 1920px.
    return AppNetworkImage(
      url: photoUrl,
      memCacheWidth: 800,
    );
  }
}
