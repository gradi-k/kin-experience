// lib/views/widgets/place_card.dart
import 'package:flutter/material.dart';
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
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = widget.place;

    final photoUrl = _getFirstPhoto(place);
    final name = _getName(place);
    final rating = _getRating(place);
    final prixRange = _getPrixRange(place);
    final isFeatured = _isFeatured(place);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: theme.cardTheme.elevation,
          shadowColor: theme.cardTheme.shadowColor,
          child: Stack(
            children: [
              // Image principale
              SizedBox(
                height: 300,
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
                        Color.fromARGB(228, 0, 0, 0),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Constants.myOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Meilleure Note',
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
                  padding: const EdgeInsets.all(12.0),
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
                            size: 16,
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
                            Text(
                              prixRange,
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
  }

  Widget _buildImage(String? photoUrl, ThemeData theme) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return Container(
        color: Colors.grey.shade300,
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 48,
          color: Colors.grey.shade500,
        ),
      );
    }

    final isAsset = photoUrl.startsWith('assets/');
    final isNetwork = photoUrl.startsWith('http://') || photoUrl.startsWith('https://');

    if (isAsset) {
      return Image.asset(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imageFallback(theme),
      );
    }

    if (isNetwork) {
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imageFallback(theme),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
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