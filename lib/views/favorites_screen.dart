import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_localizations.dart';
import '../controllers/favorites_controller.dart';
import '../controllers/places_controller.dart';
import 'widgets/place_card.dart';
import 'detail_screen.dart';

/// Écran placeholder pour les favoris.  L’intégration complète de
/// favoris peut être développée ultérieurement (stockage des lieux
/// préférés par l’utilisateur).
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final favoritesAsync = ref.watch(favoritesControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('nav_favorites')),
      ),
      body: favoritesAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(loc.translate('no_results')),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              // Déterminer la catégorie en analysant l’ID du document
              // (format: collectionName_id).  Cela permet d’ouvrir le
              // bon écran de détails et de gérer les favoris.
              final idParts = item.id.split('_');
              final catName = idParts.isNotEmpty ? idParts.first : '';
              PlaceCategory? category;
              for (final value in PlaceCategory.values) {
                if (value.collectionName == catName) {
                  category = value;
                  break;
                }
              }
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: PlaceCard(
                  place: item,
                  onTap: () {
                    if (category == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DetailScreen(
                          place: item,
                          category: category!,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erreur: $e')),
      ),
    );
  }
}