import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kin_experience/controllers/location_controller.dart';
import 'package:kin_experience/models/ad_model.dart';
import 'package:kin_experience/services/ad_service.dart';
import 'package:kin_experience/views/notifications_screen.dart';

import '../localization/app_localizations.dart';
import '../models/place_enums.dart';
import '../data/fake_data.dart';

import 'widgets/featured_carousel.dart';
import 'widgets/place_card.dart';
import 'widgets/bottom_nav_bar.dart';
import 'detail_screen.dart';
import 'category_list_screen.dart';
import 'reels_screen.dart';
import 'profile_screen.dart';
import 'global_search_screen.dart';
import 'shop_products_screen.dart';

import 'widgets/ads_banner_carousel.dart';

/// Écran principal de l’application.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedBottomIndex = 0;

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
  }

  void _onBottomNavTap(int index) {
    setState(() => _selectedBottomIndex = index);
  }

  /// ✅ Construit une liste globale de tous les contenus
  List<dynamic> _buildAllPlaces() {
    return [
      ...fakeSites,
      ...fakeRestos,
      ...fakeHotels,
      ...fakeEvents,
      ...fakeEntreprises,
      ...fakeShoppings,
    ];
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
    for (final shop in fakeShoppings) {
      list.add({'place': shop, 'category': PlaceCategory.shopping});
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

    // ✅ Global list
    final allPlaces = _buildAllPlaces();

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
          'title': loc.translate('entreprises_label'),
          'items': fakeEntreprises,
          'category': PlaceCategory.entreprise,
        },
        {
          'key': 'shop',
          'title': loc.translate('Market'),
          'items': fakeShoppings,
          'category': PlaceCategory.shopping,
        },
      ];

      final searchResults = _filteredSearchResults();

      final List<dynamic> featuredPlaces = [
        ...fakeSites.where((e) => e.isFeatured),
        ...fakeRestos.where((e) => e.isFeatured),
        ...fakeHotels.where((e) => e.isFeatured),
        ...fakeEvents.where((e) => e.isFeatured),
        ...fakeEntreprises.where((e) => e.isFeatured),
        ...fakeShoppings.where((e) => e.isFeatured),
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
        {
          'label': loc.translate('Market'),
          'icon': Icons.shopify_outlined,
          'items': fakeShoppings,
          'category': PlaceCategory.shopping,
        },
      ];

      final allItems = [
        ...fakeSites,
        ...fakeRestos,
        ...fakeHotels,
        ...fakeEvents,
        ...fakeEntreprises,
        ...fakeShoppings,
      ];



      final hasQuery = _searchController.text.trim().isNotEmpty;
      final cityAsync = ref.watch(userCityProvider);

      final adsService = AdsService();

      return Column(
        children: [
          // ==========================
          // HEADER BLEU
          // ==========================
          Container(
            padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // ✅ Mbote + City
                Row(
                  children: [

                    Column(
                      children: [
                        const SizedBox(height: 4),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.primary,
                          child: const Icon(Icons.location_pin, color: Colors.yellow),
                        ),
                      ],
                    ),

                    // Text(
                    //   'Mbote',
                    //   style: theme.textTheme.titleMedium?.copyWith(
                    //     color: Colors.white,
                    //     fontWeight: FontWeight.w600,
                    //   ),
                    //),

                    Row(
                      children: [
                        cityAsync.when(

                          data: (city) => Text(
                            city,
                            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
                          ),
                          loading: () => Text(
                            "…",
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                          ),
                          error: (_, __) => Text(
                            "Votre ville",
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                          ),

                        ),
                        // const Divider(height: 1,color: Colors.grey,thickness: 1,),

                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.notifications_none, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                        );
                      },
                    ),
                  ],
                ),


                const SizedBox(height: 5),

                // ✅ Cat icons row
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
                          if (label.toLowerCase() == 'shop') {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ShopProductsScreen()),
                            );
                            return;
                          }

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
                          width: 60,
                          margin: EdgeInsets.only(
                            left: index == 0 ? 0 : 0,
                            right: index == categoryIcons.length - 1 ? 0 : 4,
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
                                  border: Border.all(color: Colors.white.withOpacity(0.25)),
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

              ],
            ),
          ),

          // ==========================
          // SCROLL CONTENT
          // ==========================

          Expanded(
            child: hasQuery
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              padding: const EdgeInsets.only(top: 10, bottom: 80),
              children: [
                if (featuredPlaces.isNotEmpty) ...[
                  FeaturedCarousel(
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 10),
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
                      } else if (fakeEntreprises.contains(place)) {
                        category = PlaceCategory.entreprise;
                      } else {
                        category = PlaceCategory.shopping;
                      }

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(place: place, category: category),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    child: StreamBuilder<List<AdModel>>(
                      stream: adsService.watchActiveAds(),
                      builder: (context, snapshot) {
                        final ads = snapshot.data ?? const <AdModel>[];

                        // Option: si aucune pub Firebase, tu peux fallback sur fakeAds
                        // (sans casser ton design)
                        if (ads.isEmpty) {
                          return const SizedBox.shrink(); // ou AdsBannerCarousel(ads: fakeAds...)
                        }

                        return AdsBannerCarousel(
                          ads: ads,
                          autoPlay: true,
                          autoPlayInterval: const Duration(seconds: 10),
                          height: 155,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                ...sections.map((section) {
                  final title = section['title'] as String;
                  final items = section['items'] as List;
                  final category = section['category'] as PlaceCategory;

                  final totalCount = items.length;
                  final displayItems = items.length > 4 ? items.sublist(0, 4) : items;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: theme.textTheme.titleLarge?.copyWith(
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
                              width: 330,
                              margin: EdgeInsets.only(
                                left: index == 0 ? 2 : 1,
                                right: index == displayItems.length - 1 ? 2 : 1,
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
                }),
              ],
            ),
          ),
        ],
      );
    }

    // ✅ Bottom tabs mapping (4 items):
    // 0 Explore | 1 Reels | 2 Search | 3 Profile
    Widget body;
    switch (_selectedBottomIndex) {
      case 0:
        body = buildExplore();
        break;
      case 1:
        body = const ReelsScreen();
        break;
      case 2:
        body = GlobalSearchScreen(allItems: allPlaces);
        break;
      case 3:
        body = const ProfileScreen();
        break;
      default:
        body = buildExplore();
    }

    final PreferredSizeWidget? topBar = _selectedBottomIndex == 0
        ? null
        : AppBar(
      title: Text(
        'Kin City Guide',
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
}
