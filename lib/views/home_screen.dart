import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kin_experience/views/notifications_screen.dart';

import '../models/place_enums.dart';
import '../repositories/places_repository.dart';
import '../services/content_service.dart';

import 'category_list_screen.dart';
import 'detail_screen.dart';
import 'global_search_screen.dart';
import 'profile_screen.dart';
import 'reels_screen.dart';
import 'shop_products_screen.dart';

/// HomeScreen (design conservé) + données dynamiques Firestore via PlacesRepository/ContentService.
/// - Les cartes utilisent une "shape" Map<String, dynamic> compatible avec l'ancien UI (title, image, etc.)
/// - Les catégories affichées viennent de PlaceCategory.values (place_enums.dart)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ContentService _contentService;

  PlaceCategory _selectedCategory = PlaceCategory.resto;

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _searching = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _contentService = ContentService(repository: PlacesRepository());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Convertit PlaceItem -> Map compatible UI existant (detail_screen, cards, etc.)
  Map<String, dynamic> _placeToCard(PlaceItem p, {PlaceCategory? cat}) {
    return {
      'id': p.id,
      'title': p.name,
      'image': (p.mainPhotoUrl.isNotEmpty ? p.mainPhotoUrl : null) ??
          'https://picsum.photos/seed/${p.id}/600/400',
      'description': p.description,
      'rating': p.rating,
      'price': p.prixRange,
      'distance': '', // Optionnel: calculer via geo si tu as la position utilisateur
      'isFavorite': false,
      'category': (cat ?? PlaceCategoryX.fromKey(p.category)).key, // String
      'place': p, // on garde l'objet pour usage interne si nécessaire
    };
  }

  Future<void> _runSearch(String q) async {
    final query = q.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);

    try {
      // Stratégie simple: on charge par catégorie et on filtre côté client.
      final all = <PlaceItem>[];
      for (final cat in PlaceCategory.values) {
        final items = await _contentService.fetchPlaces(cat);
        all.addAll(items);
      }

      final lower = query.toLowerCase();
      final filtered = all
          .where((p) =>
      p.name.toLowerCase().contains(lower) ||
          p.description.toLowerCase().contains(lower))
          .take(60)
          .map((p) => _placeToCard(p))
          .toList();

      if (!mounted) return;
      setState(() {
        _searchResults = filtered;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur de recherche: $e")),
      );
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(v));
  }

  @override
  Widget build(BuildContext context) {
    final categories = PlaceCategory.values;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0B),
        elevation: 0,
        title: const Text(
          'Kin Experience',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Reels',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReelsScreen()),
            ),
            icon: const Icon(Icons.play_circle_outline),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            tooltip: 'Profil',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildSearchBar(),
            const SizedBox(height: 14),
            _buildCategoryRow(categories),
            const SizedBox(height: 16),

            // Si recherche active, on affiche les résultats (dynamiques)
            if (_searchCtrl.text.trim().isNotEmpty)
              _buildSearchResults()
            else ...[
              _buildSectionTitle(
                title: 'En vedette',
                action: 'Voir tout',
                onAction: () async {
                  final items =
                  await _contentService.fetchPlaces(_selectedCategory);
                  final cards = items.map((p) => _placeToCard(p)).toList();
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryListScreen(
                        title: 'En vedette • ${_selectedCategory.label}',
                        items: cards,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildFeaturedCarousel(),
              const SizedBox(height: 18),

              _buildSectionTitle(
                title: 'Recommandés',
                action: 'Explorer',
                onAction: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
                ),
              ),
              const SizedBox(height: 10),
              _buildRecommendedList(),
              const SizedBox(height: 18),

              _buildShopBanner(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white54),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Rechercher un lieu, une activité, une adresse…",
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              tooltip: 'Effacer',
              onPressed: () {
                _searchCtrl.clear();
                setState(() {
                  _searchResults = [];
                  _searching = false;
                });
              },
              icon: const Icon(Icons.close, color: Colors.white54),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(List<PlaceCategory> categories) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final isActive = cat == _selectedCategory;

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _selectedCategory = cat),
            onLongPress: () async {
              // Long press => ouvre la liste complète de cette catégorie
              final items = await _contentService.fetchPlaces(cat);
              final cards = items.map((p) => _placeToCard(p, cat: cat)).toList();
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryListScreen(
                    title: cat.label,
                    items: cards,
                  ),
                ),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF45E317) : const Color(0xFF141414),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isActive ? Colors.transparent : Colors.white10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat.icon, size: 18, color: isActive ? Colors.black : Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    cat.label,
                    style: TextStyle(
                      color: isActive ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.only(top: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_searchResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 18),
        child: Text(
          "Aucun résultat.",
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title: 'Résultats', action: 'Filtrer', onAction: () {}),
        const SizedBox(height: 10),
        ..._searchResults.map((m) => _buildListTileCard(m)).toList(),
      ],
    );
  }

  Widget _buildFeaturedCarousel() {
    return StreamBuilder<List<PlaceItem>>(
      stream: _contentService.watchPlaces(_selectedCategory),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            "Erreur: ${snap.error}",
            style: const TextStyle(color: Colors.white54),
          );
        }
        if (!snap.hasData) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final featured = snap.data!
            .where((p) => p.isFeatured)
            .take(10)
            .map((p) => _placeToCard(p, cat: _selectedCategory))
            .toList();

        if (featured.isEmpty) {
          // fallback: prendre les premiers
          featured.addAll(
            snap.data!.take(10).map((p) => _placeToCard(p, cat: _selectedCategory)),
          );
        }

        return SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: featured.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _buildFeaturedCard(featured[i]),
          ),
        );
      },
    );
  }

  Widget _buildRecommendedList() {
    return StreamBuilder<List<PlaceItem>>(
      stream: _contentService.watchPlaces(_selectedCategory),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            "Erreur: ${snap.error}",
            style: const TextStyle(color: Colors.white54),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = [...snap.data!];
        items.sort((a, b) => b.rating.compareTo(a.rating));

        final cards = items.take(12).map((p) => _placeToCard(p, cat: _selectedCategory)).toList();

        if (cards.isEmpty) {
          return const Text("Aucun contenu pour cette catégorie.", style: TextStyle(color: Colors.white54));
        }

        return Column(
          children: cards.map(_buildListTileCard).toList(),
        );
      },
    );
  }

  Widget _buildListTileCard(Map<String, dynamic> item) {
    final title = (item['title'] ?? '') as String;
    final image = (item['image'] ?? '') as String;
    final rating = (item['rating'] ?? 0.0) as num;
    final price = (item['price'] ?? '') as String;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                bottomLeft: Radius.circular(18),
              ),
              child: Image.network(
                image,
                width: 120,
                height: 92,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 120,
                  height: 92,
                  color: Colors.white10,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported, color: Colors.white38),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          price,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(Map<String, dynamic> item) {
    final title = (item['title'] ?? '') as String;
    final image = (item['image'] ?? '') as String;
    final rating = (item['rating'] ?? 0.0) as num;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
      ),
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white10,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported, color: Colors.white38),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShopBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Boutique",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                SizedBox(height: 6),
                Text(
                  "Découvre des produits sélectionnés et des souvenirs de Kinshasa.",
                  style: TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF45E317),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShopProductsScreen()),
            ),
            child: const Text("Voir"),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String action,
    required VoidCallback onAction,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(action, style: const TextStyle(color: Color(0xFF45E317), fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
