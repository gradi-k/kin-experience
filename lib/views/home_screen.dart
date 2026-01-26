import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kin_experience/controllers/location_controller.dart';
import 'package:kin_experience/controllers/places_controller.dart';
import 'package:kin_experience/controllers/notification_controller.dart';
import 'package:kin_experience/models/ad_model.dart';
import 'package:kin_experience/services/ad_service.dart';
import 'package:kin_experience/views/notifications_screen.dart';

import '../localization/app_localizations.dart';
import '../models/place_enums.dart';

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

/// Écran principal de l'application.
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // ✅ Récupérer toutes les places dynamiquement
    final allPlacesAsync = ref.watch(allPlacesProvider);

    Widget buildExplore() {
      // ✅ Récupérer les données dynamiques
      final sectionsAsync = ref.watch(homeSectionsProvider);
      final featuredAsync = ref.watch(featuredPlacesProvider);
      final cityAsync = ref.watch(userCityProvider);
      final unreadCountAsync = ref.watch(unreadNotificationsCountProvider);

      final adsService = AdsService();

      return Column(
        children: [
          // ==========================
          // HEADER VERT
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
                // ✅ Mbote + City + Notifications
                Row(
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 1),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.white.withOpacity(0.0),
                          child: const Icon(Icons.location_pin, color: Colors.yellow, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(width: 2),
                    cityAsync.when(
                      data: (city) => Text(
                        city.isNotEmpty ? city : 'Kinshasa',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      loading: () => Text(
                        "…",
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                      error: (_, __) => Text(
                        "Kinshasa",
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ),
                    const Spacer(),
                    // ✅ Notifications avec badge
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                            );
                          },
                        ),
                        unreadCountAsync.when(
                          data: (count) {
                            if (count == 0) return const SizedBox.shrink();
                            return Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  count > 99 ? '99+' : count.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                // ✅ Icônes de catégories (statiques pour navigation)
                SizedBox(
                  height: 78,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      final categories = [
                        {
                          'label': ('Hotels'),
                          'icon': Icons.hotel,
                          'category': PlaceCategory.hotel,
                        },
                        {
                          'label': ('Restos'),
                          'icon': Icons.restaurant,
                          'category': PlaceCategory.resto,
                        },
                        {
                          'label': ('Events'),
                          'icon': Icons.event,
                          'category': PlaceCategory.event,
                        },
                        {
                          'label': ('Sites'),
                          'icon': Icons.landscape,
                          'category': PlaceCategory.site,
                        },
                        {
                          'label': loc.translate('entreprises_label'),
                          'icon': Icons.home_work,
                          'category': PlaceCategory.entreprise,
                        },
                        {
                          'label': loc.translate('Market'),
                          'icon': Icons.shopify_outlined,
                          'category': PlaceCategory.shopping,
                        },
                      ];

                      final cat = categories[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          left: index == 0 ? 0 : 8,
                          right: index == 0 ? 4 :8,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CategoryListScreen(
                                  title: cat['label'] as String,
                                  category: cat['category'] as PlaceCategory,
                                ),
                              ),
                            );
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    shape: BoxShape.circle, // Devient un cercle parfait
                                    border: Border.all(
                                      color: Colors.white,    // Couleur du contour
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Icon(
                                    cat['icon'] as IconData,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cat['label'] as String,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
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
            child: featuredAsync.when(
              data: (featuredPlaces) {
                print('🌟 Featured places: ${featuredPlaces.length}');
                return sectionsAsync.when(
                  data: (sections) {
                    print('📦 Total sections: ${sections.length}');
                    return ListView(
                      padding: const EdgeInsets.only(top: 10, bottom: 80),
                      children: [
                        // ✅ Featured Carousel
                        if (featuredPlaces.isNotEmpty) ...[
                          FeaturedCarousel(
                            autoPlay: true,
                            autoPlayInterval: const Duration(seconds: 10),
                            featuredPlaces: featuredPlaces,
                            onTap: (place) {
                              final category = inferCategory(place) ?? PlaceCategory.site;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DetailScreen(place: place, category: category),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),

                          // ✅ Ads Banner
                          Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 8),
                            child: StreamBuilder<List<AdModel>>(
                              stream: adsService.watchActiveAds(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  print('❌ Ads error: ${snapshot.error}');
                                }
                                final ads = snapshot.data ?? const <AdModel>[];
                                print('📢 Ads loaded: ${ads.length}');

                                if (ads.isEmpty) {
                                  return const SizedBox.shrink();
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

                        // ✅ Sections dynamiques (Sites, Restos, Hotels, etc.)
                        ...sections.map((section) {
                          // ✅ HomeSection a les propriétés: key, titleKey, items, category
                          final titleKey = section.titleKey;
                          final title = loc.translate(titleKey);
                          final items = section.items;
                          final category = section.category;

                          print('📦 Section ${section.key}: ${items.length} items');

                          if (items.isEmpty) return const SizedBox.shrink();

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
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) {
                    print('❌ Sections error: $e');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.explore_outlined,
                              size: 80,
                              color: theme.colorScheme.primary.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun contenu disponible',
                              style: theme.textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) {
                print('❌ Featured error: $e');
                return const Center(child: Text('Erreur de chargement'));
              },
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
      // ✅ Passer les données dynamiques à GlobalSearchScreen
        body = allPlacesAsync.when(
          data: (allPlaces) {
            print('🔍 Search: ${allPlaces.length} places');
            return GlobalSearchScreen(allItems: allPlaces);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) {
            print('❌ AllPlaces error: $e');
            return const GlobalSearchScreen(allItems: []);
          },
        );
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