import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// Widget réutilisable pour afficher un lieu (site, restaurant, hôtel, etc.).
/// Il affiche l’image principale, le titre, la note, une étiquette de
/// prix/catégorie et un badge « Mis en avant » lorsqu’approprié.  Un
/// [VoidCallback] peut être passé pour gérer le tap (ouvrir les détails ou
/// lancer Google Maps par exemple).
class PlaceCard extends StatelessWidget {
  final dynamic place;
  final VoidCallback? onTap;

  const PlaceCard({
    Key? key,
    required this.place,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: theme.cardTheme.elevation,
        child: Stack(
          children: [
            // Image principale
            SizedBox(
              height: 200,
              width: double.infinity,
              child: place.photos.isNotEmpty
                  ? (place.photos.first.toString().startsWith('assets/')
                      ? Image.asset(
                          place.photos.first,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          place.photos.first,
                          fit: BoxFit.cover,
                        ))
                  : Container(
                      color: Colors.grey.shade300,
                    ),
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
                      Color.fromARGB(200, 0, 0, 0),
                    ],
                  ),
                ),
              ),
            ),
            // Badge « Mis en avant »
            if (place.isFeatured)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Constants.airbnbRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Mis en avant',
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
                      place.nom,
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
                          place.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          place.prixRange,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}