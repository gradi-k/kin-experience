// lib/views/home_screen.dart
// ✅ VERSION FINALE CORRIGÉE
// 1. Badge notifications fonctionnel
// 2. SANS search bar dans header
// 3. Contour blanc icônes catégories

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cityguide/controllers/location_controller.dart';
import 'package:cityguide/controllers/places_controller.dart';
import 'package:cityguide/controllers/notification_controller.dart';
import 'package:cityguide/models/ad_model.dart';
import 'package:cityguide/services/ad_service.dart';
import 'package:cityguide/views/notifications/notifications_screen.dart';

import '../localization/app_localizations.dart';
import '../models/place_enums.dart';

import 'widgets/featured_carousel.dart';
import 'widgets/place_card.dart';
import 'widgets/bottom_nav_bar.dart';
import 'detail_screen.dart';
import 'category/category_list_screen.dart';
import 'reels/reels_screen.dart';
import 'profile/profile_screen.dart';
import 'global_search_screen.dart';
import 'shops/shop_products_screen.dart';

import 'widgets/ads_banner_carousel.dart';

class ResponsiveSize {
  final BuildContext context;
  late final double screenWidth;
  late final double screenHeight;
  late final bool isSmallScreen;
  late final bool isMediumScreen;
  late final bool isLargeScreen;

  ResponsiveSize(this.context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;

    isSmallScreen = screenWidth < 360;
    isMediumScreen = screenWidth >= 360 && screenWidth < 600;
    isLargeScreen = screenWidth >= 600;
  }

  double get padding => isSmallScreen ? 12 : (isMediumScreen ? 16 : 20);
  double get paddingSmall => isSmallScreen ? 8 : (isMediumScreen ? 10 : 12);
  double get paddingLarge => isSmallScreen ? 20 : (isMediumScreen ? 24 : 28);

  double get iconSmall => isSmallScreen ? 16 : (isMediumScreen ? 18 : 20);
  double get iconMedium => isSmallScreen ? 20 : (isMediumScreen ? 24 : 28);
  double get iconLarge => isSmallScreen ? 45 : (isMediumScreen ? 50 : 55);

  double text(double baseSize) {
    if (isSmallScreen) return baseSize * 0.9;
    if (isLargeScreen) return baseSize * 1.1;
    return baseSize;
  }

  double get headerHeight => isSmallScreen ? 70 : (isMediumScreen ? 78 : 86);
  double get categoryHeight => isSmallScreen ? 145 : (isMediumScreen ? 155 : 165);
  double get cardHeight => isSmallScreen ? 230 : (isMediumScreen ? 250 : 270);
  double get cardWidth => isSmallScreen ? 300 : (isMediumScreen ? 330 : 360);

  double get radiusSmall => isSmallScreen ? 10 : (isMediumScreen ? 12 : 14);
  double get radiusMedium => isSmallScreen ? 14 : (isMediumScreen ? 16 : 18);
  double get radiusLarge => isSmallScreen ? 20 : (isMediumScreen ? 24 : 28);
}

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
    final allPlacesAsync = ref.watch(allPlacesProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    Widget buildExplore() {
      final sectionsAsync = ref.watch(homeSectionsProvider);
      final featuredAsync = ref.watch(featuredPlacesProvider);
      final cityAsync = ref.watch(userCityCommuneProvider);
      final unreadCountAsync = ref.watch(unreadNotificationsCountProvider);

      final adsService = AdsService();

      return Column(
          children: [
      // HEADER VERT
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
      // City + Notifications
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
      data: (cityCommune) => Text(
      cityCommune.isNotEmpty ? cityCommune : 'Kinshasa',
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
      // ✅ Badge notifications ULTRA-VISIBLE
      unreadCountAsync.when(
      data: (count) {
      print('🔔 Badge count: $count');  // Debug
      return Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          if (count > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Center(
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
      },
      loading: () => IconButton(
      icon: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
      onPressed: () {
      Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
      },
      ),
      error: (_, __) => IconButton(
      icon: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
      onPressed: () {
      Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
      },
      ),
      ),
      ],
      ),

      const SizedBox(height: 12),

      // ✅ ICÔNES CATÉGORIES avec contour blanc
      SizedBox(
      height: 78,
      child: LayoutBuilder(
      builder: (context, constraints) {
      final categories = [
      {'label': 'Hotels', 'icon': Icons.hotel, 'category': PlaceCategory.hotel},
      {'label': 'Restos', 'icon': Icons.restaurant, 'category': PlaceCategory.resto},
      {'label': 'Sites', 'icon': Icons.landscape, 'category': PlaceCategory.site},
      {'label': 'Events', 'icon': Icons.event, 'category': PlaceCategory.event},
      {'label': 'Business', 'icon': Icons.home_work, 'category': PlaceCategory.entreprise},
      {'label': 'Market', 'icon': Icons.shopping_bag_outlined, 'category': PlaceCategory.shopping},
      ];

      const double iconWidth = 70.0;
      final double totalWidth = categories.length * iconWidth;
      final bool needsScroll = totalWidth > constraints.maxWidth;

      return needsScroll
      ? ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      itemBuilder: (context, index) => _buildCategoryIcon(
      categories[index],
      index,
      categories.length,
      theme,
      ),
      )
          : Center(
      child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: categories.asMap().entries.map((entry) {
      return _buildCategoryIcon(
      entry.value,
      entry.key,
      categories.length,
      theme,
      );
      }).toList(),
      ),
      );
      },
      ),
      ),
      ],
      ),
      ),

      // CONTENU SCROLLABLE
      Expanded(
      child: featuredAsync.when(
      data: (featured) {
      return SingleChildScrollView(
      child: sectionsAsync.when(
      data: (sections) {
      return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      const SizedBox(height: 16),

      // Featured carousel
      if (featured.isNotEmpty) ...[
      Padding(
      padding: EdgeInsets.symmetric(
      horizontal: screenWidth >= 900 ? 8 : 0,
      ),
      child: FeaturedCarousel(
      featuredPlaces: featured,
      onTap: (place) {
      Navigator.of(context).push(
      MaterialPageRoute(
      builder: (_) => DetailScreen(
      place: place,
      category: PlaceCategory.site,
      ),
      ),
      );
      },
      ),
      ),
      ],

      // Ads banner
      if (featured.isNotEmpty) ...[
      Padding(
      padding: EdgeInsets.symmetric(
      horizontal: screenWidth >= 900 ? 8 : 0,
      ),
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

      // Sections dynamiques
      ...sections.map((section) {
      final titleKey = section.titleKey;
      final title = loc.translate(titleKey);
      final items = section.items;
      final category = section.category;

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
      ));
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

    // Bottom tabs
    Widget body;
    switch (_selectedBottomIndex) {
      case 0:
        body = buildExplore();
        break;
      case 1:
        body = const ReelsScreen();
        break;
      case 2:
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
        'City Guide',
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

  // ✅ Icône catégorie avec CONTOUR BLANC
  Widget _buildCategoryIcon(
      Map<String, dynamic> cat,
      int index,
      int totalCount,
      ThemeData theme,
      ) {
    return Padding(
      padding: EdgeInsets.only(
        left: index == 0 ? 4 : 4,
        right: index == totalCount - 1 ? 4 : 7,
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
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                border: Border.all(  // ✅ CONTOUR BLANC AJOUTÉ
                  color: Colors.white,
                  width: 0.4,
                ),
              ),
              child: Icon(
                cat['icon'] as IconData,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              cat['label'] as String,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}