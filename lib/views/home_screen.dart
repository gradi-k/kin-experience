import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kin_experience/controllers/places_controller.dart';

import '../utils/constants.dart';
import '../localization/app_localizations.dart';
import '../data/fake_data.dart';
import 'widgets/featured_carousel.dart';
import 'widgets/place_card.dart';
import 'widgets/bottom_nav_bar.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'detail_screen.dart';
import 'category_list_screen.dart';

/// Écran principal de l’application.
/// - Header bleu avec user / notification / recherche + filtres par icônes (dans le header)
/// - “Incontournables” (carrousel) scrolle avec le reste
/// - Sections par catégories en listes horizontales limitées à 4 avec “Voir plus”
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedBottomIndex = 0;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.text = '';
      }
    });
  }

  void _onSearchChanged(String value) {
    setState(() {});
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedBottomIndex = index;
    });
  }

  List<Map<String, dynamic>> _allPlacesWithCategory() {
    final list = <Map<String, dynamic>>[];
    for (final site in fakeSites) {
      list.add({'place': site, 'category': PlaceCategory.site});
    }
    for (final resto in fakeRestos) {
      list.add({'place': resto, 'category': PlaceCategory.resto});
    }
    for (final hotel in fakeHotels) {
      list.add({'place': hotel, 'category': PlaceCategory.hotel});
    }
    for (final event in fakeEvents) {
      list.add({'place': event, 'category': PlaceCategory.event});
    }
    for (final ent in fakeEntreprises) {
      list.add({'place': ent, 'category': PlaceCategory.entreprise});
    }
    return list;
  }

  List<Map<String, dynamic>> _filteredSearchResults() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return [];
    return _allPlacesWithCategory()
        .where((item) =>
        item['place'].nom.toString().toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    Widget buildExplore() {
      final sections = [
        {
          'key': 'sites',
          'title': loc.translate('sites_label'),
          'items': fakeSites,
          'category': PlaceCategory.site,
        },
        {
          'key': 'restos',
          'title': loc.translate('restos_label'),
          'items': fakeRestos,
          'category': PlaceCategory.resto,
        },
        {
          'key': 'hotels',
          'title': loc.translate('hotels_label'),
          'items': fakeHotels,
          'category': PlaceCategory.hotel,
        },
        {
          'key': 'events',
          'title': loc.translate('events_label'),
          'items': fakeEvents,
          'category': PlaceCategory.event,
        },
        {
          'key': 'entreprises',
          'title': loc.translate('entreprises_label'), // = Immo dans tes traductions
          'items': fakeEntreprises,
          'category': PlaceCategory.entreprise,
        },
      ];

      final searchResults = _filteredSearchResults();

      final List<dynamic> featuredPlaces = [
        ...fakeSites.where((e) => e.isFeatured),
        ...fakeRestos.where((e) => e.isFeatured),
        ...fakeHotels.where((e) => e.isFeatured),
        ...fakeEvents.where((e) => e.isFeatured),
        ...fakeEntreprises.where((e) => e.isFeatured),
      ];

      final List<Map<String, dynamic>> categoryIcons = [
        {
          'label': loc.translate('hotels_label'),
          'icon': Icons.hotel,
          'items': fakeHotels,
          'category': PlaceCategory.hotel,
        },
        {
          'label': loc.translate('restos_label'),
          'icon': Icons.restaurant,
          'items': fakeRestos,
          'category': PlaceCategory.resto,
        },
        {
          'label': loc.translate('events_label'),
          'icon': Icons.event,
          'items': fakeEvents,
          'category': PlaceCategory.event,
        },
        {
          'label': loc.translate('sites_label'),
          'icon': Icons.landscape,
          'items': fakeSites,
          'category': PlaceCategory.site,
        },
        {
          'label': loc.translate('entreprises_label'),
          'icon': Icons.home_work,
          'items': fakeEntreprises,
          'category': PlaceCategory.entreprise,
        },
      ];

      // ✅ Header (fixe) + Contenu scrollable (ListView)
      return Column(
        children: [
          // ==========================
          // HEADER BLEU (FIXE)
          // user + notif + search
          // + catégories (dans le header)
          // ==========================
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
                // Top bar
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
                        // Text(
                        //   'Kinshasa',
                        //   style: theme.textTheme.bodyMedium?.copyWith(
                        //     color: Colors.white70,
                        //   ),
                       // ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.notifications_none,
                          color: Colors.white),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: _toggleSearch,
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ✅ Icônes catégories (DANS LE HEADER BLEU)
                SizedBox(
                  height: 78,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categoryIcons.length,
                    itemBuilder: (context, index) {
                      final iconData = categoryIcons[index];
                      final label = iconData['label'] as String;
                      final category = iconData['category'] as PlaceCategory;
                      final items = iconData['items'] as List;

                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CategoryListScreen(
                                title: label,
                                items: items,
                                category: category,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 78,
                          margin: EdgeInsets.only(
                            left: index == 0 ? 0 : 10,
                            right: index == categoryIcons.length - 1 ? 0 : 0,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.25),
                                  ),
                                ),
                                child: Icon(
                                  iconData['icon'] as IconData,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
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

                // Search field (dans le header) apparaît au clic
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isSearching
                      ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      key: const ValueKey('searchField'),
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: loc.translate('search_hint'),
                        hintStyle: const TextStyle(color: Colors.white70),
                        prefixIcon:
                        const Icon(Icons.search, color: Colors.white),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // ==========================
          // CONTENU (SCROLL)
          // Incontournables + sections
          // ==========================
          Expanded(
            child: _isSearching && _searchController.text.trim().isNotEmpty
                ? ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 80),
              children: [
                if (searchResults.isEmpty)
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
                  ...searchResults.map((item) {
                    final place = item['place'];
                    final category = item['category'] as PlaceCategory;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                  }),
              ],
            )
                : ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 80),
              children: [
                // ✅ “Incontournables” DANS LE SCROLL (plus fixe)
                if (featuredPlaces.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    // child: Text(
                    //    loc.translate('featured_section_title'),
                    //   style: theme.textTheme.titleLarge?.copyWith(
                    //     fontWeight: FontWeight.bold,
                    //   ),
                    // ),
                  ),
                  FeaturedCarousel(
                    featuredPlaces: featuredPlaces,
                    onTap: (place) {
                      PlaceCategory category;
                      if (fakeSites.contains(place)) {
                        category = PlaceCategory.site;
                      } else if (fakeRestos.contains(place)) {
                        category = PlaceCategory.resto;
                      } else if (fakeHotels.contains(place)) {
                        category = PlaceCategory.hotel;
                      } else if (fakeEvents.contains(place)) {
                        category = PlaceCategory.event;
                      } else {
                        category = PlaceCategory.entreprise;
                      }
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
                  const SizedBox(height: 8),
                ],

                // Sections normales
                ...sections.map((section) {
                  final title = section['title'] as String;
                  final items = section['items'] as List;
                  final category = section['category'] as PlaceCategory;

                  final totalCount = items.length;
                  final displayItems =
                  items.length > 4 ? items.sublist(0, 4) : items;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style:
                                theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (totalCount > displayItems.length)
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => CategoryListScreen(
                                        title: title,
                                        items: items,
                                        category: category,
                                      ),
                                    ),
                                  );
                                },
                                child: Text(loc.translate('see_more')),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 250,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: displayItems.length,
                          itemBuilder: (context, index) {
                            final place = displayItems[index];
                            return Container(
                              width: 220,
                              margin: EdgeInsets.only(
                                left: index == 0 ? 16 : 8,
                                right: index == displayItems.length - 1
                                    ? 16
                                    : 8,
                              ),
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
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      );
    }

    Widget body;
    switch (_selectedBottomIndex) {
      case 0:
        body = buildExplore();
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
        body = buildExplore();
    }

    final PreferredSizeWidget? topBar = _selectedBottomIndex == 0
        ? null
        : AppBar(
      title: Text(
        'Kin-Experience',
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
        return Icons.home_work;
      default:
        return Icons.place;
    }
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1).toLowerCase() : s;
}
