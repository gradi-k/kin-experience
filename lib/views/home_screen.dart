// lib/views/home_screen.dart
// ✅ VERSION FINALE CORRIGÉE
// 1. Badge notifications fonctionnel
// 2. SANS search bar dans header
// 3. Contour blanc icônes catégories

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cityguide/controllers/ads_controller.dart';
import 'package:cityguide/controllers/categories_controller.dart';
import 'package:cityguide/controllers/connectivity_controller.dart';
import 'package:cityguide/controllers/location_controller.dart';
import 'package:cityguide/controllers/places_controller.dart';
import 'package:cityguide/controllers/notification_controller.dart';
import 'package:cityguide/views/notifications/notifications_screen.dart';

import '../localization/app_localizations.dart';
import '../models/category_config.dart';

import 'widgets/featured_carousel.dart';
import 'widgets/place_card.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/error_retry.dart';
import 'widgets/skeletons.dart';
import 'detail_screen.dart';
import 'category/category_list_screen.dart';
import 'map/map_screen.dart';
import 'reels/reels_screen.dart';
import 'profile/profile_screen.dart';
import 'global_search_screen.dart';

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

/// Nombre de catégories dépliées en sections détaillées sur la home.
///
/// Les autres restent accessibles par la rangée d'icônes du header et par la
/// feuille « toutes les catégories » : avec une dizaine de catégories, tout
/// déplier rendrait la page interminable.
const int kHomeMaxSections = 5;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedBottomIndex = 0;

  void _onBottomNavTap(int index) {
    setState(() => _selectedBottomIndex = index);
  }

  Future<void> _refreshHome() async {
    // Invalider la famille entière relance les sections de toutes les
    // catégories, quel qu'en soit le nombre.
    ref.invalidate(categoriesProvider);
    ref.invalidate(homePlacesByCategoryProvider);
    ref.invalidate(featuredPlacesProvider);
    ref.invalidate(activeAdsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final localeCode = Localizations.localeOf(context).languageCode;

    Widget buildExplore() {
      final categoriesAsync = ref.watch(categoriesProvider);
      final sectionsAsync = ref.watch(homeSectionsProvider);
      final featuredAsync = ref.watch(featuredPlacesProvider);
      final adsAsync = ref.watch(activeAdsProvider);
      final cityAsync = ref.watch(userCityCommuneProvider);
      final unreadCountAsync = ref.watch(unreadNotificationsCountProvider);
      final isOffline = ref.watch(isOfflineProvider).value ?? false;

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
      // ✅ Carte « Autour de moi »
      IconButton(
      icon: const Icon(Icons.map_outlined, color: Colors.white, size: 26),
      tooltip: 'Autour de moi',
      onPressed: () {
      Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MapScreen()),
      );
      },
      ),
      // ✅ Badge notifications ULTRA-VISIBLE
      unreadCountAsync.when(
      data: (count) {
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

      // ✅ ICÔNES CATÉGORIES avec contour blanc — pilotées par Firestore :
      // toutes les catégories actives sont ici, même celles qui n'ont pas de
      // section détaillée plus bas.
      SizedBox(
      height: 78,
      child: categoriesAsync.when(
      data: (categories) {
      if (categories.isEmpty) return const SizedBox.shrink();

      return LayoutBuilder(
      builder: (context, constraints) {
      const double iconWidth = 70.0;
      final bool needsScroll =
      categories.length * iconWidth > constraints.maxWidth;

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
      );
      },
      loading: () => const CategoryIconsSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      ),
      ),
      ],
      ),
      ),

      // Bandeau hors-ligne discret
      if (isOffline)
      Container(
      width: double.infinity,
      color: Colors.orange.shade800,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
      const Icon(Icons.cloud_off, color: Colors.white, size: 16),
      const SizedBox(width: 8),
      Text(
      loc.translate('offline_banner'),
      style: const TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      ),
      ),
      ],
      ),
      ),

      // CONTENU SCROLLABLE
      Expanded(
      child: RefreshIndicator(
      onRefresh: _refreshHome,
      child: featuredAsync.when(
      data: (featured) {
      return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
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
      builder: (_) => DetailScreen(place: place),
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
      child: adsAsync.maybeWhen(
      data: (ads) {
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
      orElse: () => const SizedBox.shrink(),
      ),
      ),
      const SizedBox(height: 12),
      ],

      // Sections détaillées — plafonnées : au-delà, la page deviendrait
      // interminable. Les catégories restantes restent joignables par la
      // rangée d'icônes du header et par « Voir toutes les catégories ».
      ...sections.take(kHomeMaxSections).map((section) {
      final title = section.category.labelFor(localeCode);
      final items = section.items;

      final displayItems = items.length > 4 ? items.sublist(0, 4) : items;

      return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
      children: [
      Icon(
      section.category.icon,
      size: 20,
      color: theme.colorScheme.primary,
      ),
      const SizedBox(width: 8),
      Expanded(
      child: Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.bold,
      ),
      ),
      ),
      if (items.length > displayItems.length)
      TextButton(
      onPressed: () {
      Navigator.of(context).push(
      MaterialPageRoute(
      builder: (_) =>
      CategoryListScreen(categoryKey: section.key),
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
      builder: (_) => DetailScreen(place: place),
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

      // Accès aux catégories non dépliées ci-dessus.
      if (sections.length > kHomeMaxSections)
      Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: OutlinedButton.icon(
      onPressed: () => _showAllCategoriesSheet(
      sections.map((s) => s.category).toList(),
      ),
      icon: const Icon(Icons.grid_view_rounded, size: 18),
      label: Text(
      '${loc.translate('see_all_categories')} '
      '(${sections.length - kHomeMaxSections})',
      ),
      style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(44),
      ),
      ),
      ),

      const SizedBox(height: 16),
      ],
      );
      },
      loading: () => const HomeSkeleton(),
      error: (e, _) {
      debugPrint('❌ Sections error: $e');
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
      loading: () => const HomeSkeleton(),
      error: (e, _) {
      debugPrint('❌ Featured error: $e');
      return ErrorRetryWidget(
      message: 'Erreur de chargement du contenu.',
      onRetry: _refreshHome,
      );
      },
      ),
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
        // GlobalSearchScreen s'abonne lui-même à allPlacesProvider (autoDispose) :
        // les listeners plein-collection ne vivent que sur l'onglet recherche.
        body = const GlobalSearchScreen();
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

  /// Grille de toutes les catégories, pour joindre celles qui n'ont pas de
  /// section dépliée sur la home.
  void _showAllCategoriesSheet(List<CategoryConfig> categories) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final localeCode = Localizations.localeOf(context).languageCode;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.translate('see_all_categories'),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: categories.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 110,
                      childAspectRatio: 0.95,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CategoryListScreen(categoryKey: cat.key),
                            ),
                          );
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: (cat.color ??
                                      theme.colorScheme.primary)
                                  .withOpacity(0.12),
                              child: Icon(
                                cat.icon,
                                color: cat.color ?? theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              cat.labelFor(localeCode),
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ Icône catégorie avec CONTOUR BLANC
  Widget _buildCategoryIcon(
      CategoryConfig cat,
      int index,
      int totalCount,
      ThemeData theme,
      ) {
    final label = cat.labelFor(Localizations.localeOf(context).languageCode);

    return Padding(
      padding: EdgeInsets.only(
        left: index == 0 ? 4 : 4,
        right: index == totalCount - 1 ? 4 : 7,
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CategoryListScreen(categoryKey: cat.key),
            ),
          );
        },
        child: SizedBox(
          width: 62,
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
                  cat.icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}