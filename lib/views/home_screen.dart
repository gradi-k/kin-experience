import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../controllers/places_controller.dart';
import '../models/site.dart';
import '../utils/constants.dart';
import '../localization/app_localizations.dart';
import 'widgets/featured_carousel.dart';
import 'widgets/place_card.dart';
import 'widgets/bottom_nav_bar.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'detail_screen.dart';

/// Écran principal de l’application.  Il combine la barre de recherche,
/// la sélection de catégories, la section « Incontournables » et la liste
/// des autres lieux.  L’état est géré via Riverpod afin de séparer la
/// logique du rendu.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Index de la catégorie sélectionnée
  int _selectedCategoryIndex = 0;
  // Index de la page de la barre de navigation inférieure
  int _selectedBottomIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentCategory();
  }

  /// Charge la catégorie actuelle via le contrôleur
  void _loadCurrentCategory() {
    final category = PlaceCategory.values[_selectedCategoryIndex];
    ref.read(placesControllerProvider.notifier).load(category);
  }

  /// Handler lorsqu’une catégorie est tapée
  void _onCategoryTap(int index) {
    if (index == _selectedCategoryIndex) return;
    setState(() {
      _selectedCategoryIndex = index;
    });
    _loadCurrentCategory();
  }

  /// Handler pour la barre de navigation inférieure
  void _onBottomNavTap(int index) {
    setState(() {
      _selectedBottomIndex = index;
    });
    // Ici on pourrait naviguer vers d'autres écrans (Favoris, Profil, Paramètres)
  }

  /// Ouvre Google Maps aux coordonnées fournies
  Future<void> _openMaps(double latitude, double longitude) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final placesAsync = ref.watch(placesControllerProvider);

    // Séparer les éléments mis en avant des autres une fois les données chargées
    List<dynamic> featured = [];
    List<dynamic> others = [];
    placesAsync.whenData((data) {
      featured = data.where((element) => element.isFeatured).toList();
      others = data.where((element) => !element.isFeatured).toList();
    });

    Widget exploreContent() {
      return Column(
        children: [
          // En-tête personnalisé avec avatar, localisation et barre de recherche
          Container(
            padding: const EdgeInsets.only(
              top: 32,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.onPrimary,
                      child: const Icon(Icons.person, color: Colors.black),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenue',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Kinshasa',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Barre de recherche intégrée
                TextField(
                  decoration: InputDecoration(
                    hintText: loc.translate('search_hint'),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {},
                ),
                const SizedBox(height: 16),
                // Catégories (icônes circulaires)
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: Constants.categories.length,
                    itemBuilder: (context, index) {
                      final categoryName = Constants.categories[index];
                      final isSelected = index == _selectedCategoryIndex;
                      final icon = _categoryIcon(categoryName);
                      return GestureDetector(
                        onTap: () => _onCategoryTap(index),
                        child: Container(
                          width: 70,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : theme.colorScheme.secondary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  icon,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                loc.translate('${categoryName}_label'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Contenu principal
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _loadCurrentCategory();
              },
              child: placesAsync.when(
                data: (list) {
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 80, top: 8),
                    children: [
                      if (featured.isNotEmpty)
                        FeaturedCarousel(
                          featuredPlaces: featured,
                          onTap: (place) {
                            final category =
                                PlaceCategory.values[_selectedCategoryIndex];
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
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          loc.translate(
                              'all_${Constants.categories[_selectedCategoryIndex]}'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (others.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              loc.translate('no_results'),
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        )
                      else
                        ...others.map((place) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: PlaceCard(
                                place: place,
                                onTap: () {
                                  final category =
                                      PlaceCategory
                                          .values[_selectedCategoryIndex];
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
                            )),
                    ],
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          loc.translate('error_occurred'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadCurrentCategory,
                          child: Text(loc.translate('retry')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Détermine le contenu en fonction de l’onglet sélectionné
    Widget body;
    switch (_selectedBottomIndex) {
      case 0:
        body = exploreContent();
        break;
      case 1:
        body = const FavoritesScreen();
        break;
      case 2:
        body = const ProfileScreen();
        break;
      case 3:
        body = const SettingsScreen();
        break;
      default:
        body = exploreContent();
    }
    // Pour l’onglet « Explorer », nous supprimons la barre d’app afin de
    // privilégier un en‑tête personnalisé.  Pour les autres onglets,
    // l’appbar standard est conservée.
    final PreferredSizeWidget? topBar = _selectedBottomIndex == 0
        ? null
        : AppBar(
            title: Text(
              'Kin‑Experience',
              style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            centerTitle: true,
          );
    return Scaffold(
      appBar: topBar,
      body: body,
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedBottomIndex,
        onChanged: _onBottomNavTap,
      ),
    );
  }

  /// Retourne une icône appropriée pour chaque catégorie.
  IconData _categoryIcon(String category) {
    switch (category) {
      case 'sites':
        return Icons.landscape;
      case 'restos':
        return Icons.restaurant;
      case 'hotels':
        return Icons.hotel;
      case 'events':
        return Icons.event;
      case 'entreprises':
        return Icons.storefront;
      default:
        return Icons.place;
    }
  }

  /// Capitalise la première lettre d’une chaîne.
  String _capitalize(String s) => s.isNotEmpty
      ? s[0].toUpperCase() + s.substring(1).toLowerCase()
      : s;
}