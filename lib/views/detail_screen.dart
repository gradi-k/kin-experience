import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/places_controller.dart';
import '../controllers/favorites_controller.dart';
import '../localization/app_localizations.dart';
import '../utils/constants.dart';

/// Écran affichant le détail d’un lieu (site, restaurant, hôtel, etc.).
/// On y passe l’objet [place] ainsi que sa [category] pour gérer
/// l’ajout aux favoris.  L’interface comprend un carrousel d’images,
/// le titre, la note, la fourchette de prix, la description et des
/// boutons pour ouvrir Google Maps et ajouter/supprimer des favoris.
class DetailScreen extends ConsumerWidget {
  final dynamic place;
  final PlaceCategory category;

  const DetailScreen({Key? key, required this.place, required this.category})
      : super(key: key);

  Future<void> _openMaps() async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${place.latitude},${place.longitude}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final favoritesAsync = ref.watch(favoritesControllerProvider);
    final favoritesNotifier =
        ref.read(favoritesControllerProvider.notifier);
    final isFav = favoritesNotifier.isFavorite(place, category);
    return Scaffold(
      appBar: AppBar(
        title: Text(place.nom),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Constants.airbnbRed : null,
            ),
            onPressed: () async {
              await favoritesNotifier.toggleFavorite(place, category);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Carrousel d’images
          if (place.photos.isNotEmpty)
            SizedBox(
              height: 250,
              child: PageView.builder(
                itemCount: place.photos.length,
                itemBuilder: (context, index) {
                  final photo = place.photos[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: photo.toString().startsWith('assets/')
                        ? Image.asset(photo, fit: BoxFit.cover)
                        : Image.network(photo, fit: BoxFit.cover),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Text(
            place.nom,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.star, color: Colors.yellow.shade600, size: 20),
              const SizedBox(width: 4),
              Text(
                place.rating.toStringAsFixed(1),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 12),
              Text(
                place.prixRange,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            place.description,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openMaps,
            icon: const Icon(Icons.map),
            label: Text('S’y rendre'),
          ),
        ],
      ),
    );
  }
}