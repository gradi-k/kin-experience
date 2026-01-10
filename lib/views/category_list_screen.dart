import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/places_controller.dart';
import '../localization/app_localizations.dart';
import '../views/widgets/place_card.dart';
import 'detail_screen.dart';

/// Écran affichant la liste complète des lieux d’une catégorie.
/// On passe le titre, la catégorie et les éléments à afficher.
class CategoryListScreen extends ConsumerWidget {
  final String title;
  final List<dynamic> items;
  final PlaceCategory category;

  const CategoryListScreen({
    Key? key,
    required this.title,
    required this.items,
    required this.category,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final place = items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: PlaceCard(
              place: place,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DetailScreen(
                      place: place,
                      category: category,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

}