// lib/views/global_search_screen.dart
// ✅ VERSION MODIFIÉE avec filtre par ville/localisation

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/places_controller.dart';
import '../models/place_enums.dart';
import '../models/site.dart';
import '../models/resto.dart';
import '../models/hotel.dart';
import '../models/event.dart';
import '../models/entreprise.dart';
import '../models/shopping.dart';
import 'detail_screen.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  final List<dynamic>? allItems;

  const GlobalSearchScreen({
    super.key,
    this.allItems,
  });

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  PlaceCategory? _categoryFilter;
  String? _locationFilter;  // ✅ NOUVEAU : Filtre par ville/commune

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------------------
  // SAFE getters (dynamic)
  // ---------------------------
  T? _tryGet<T>(dynamic obj, T Function() getter) {
    try {
      return getter();
    } catch (_) {
      return null;
    }
  }

  String _nameOf(dynamic p) =>
      _tryGet(p, () => p.nom.toString())?.trim() ??
          _tryGet(p, () => p.name.toString())?.trim() ??
          '';

  String _descOf(dynamic p) =>
      _tryGet(p, () => p.description.toString())?.trim() ??
          _tryGet(p, () => p.desc.toString())?.trim() ??
          '';

  String _imageOf(dynamic p) {
    try {
      final photos = p.photos;

      if (photos is String) {
        return photos.isNotEmpty ? photos : '';
      }

      if (photos is List && photos.isNotEmpty) {
        final first = photos.first;
        if (first is String && first.isNotEmpty) {
          return first;
        }
        return first?.toString() ?? '';
      }
    } catch (_) {}

    return _tryGet(p, () => p.image.toString())?.trim() ??
        _tryGet(p, () => p.imageUrl.toString())?.trim() ??
        _tryGet(p, () => p.photo.toString())?.trim() ??
        _tryGet(p, () => p.cover.toString())?.trim() ??
        '';
  }

  String _addressOf(dynamic p) =>
      _tryGet(p, () => p.address.toString())?.trim() ??
          _tryGet(p, () => p.adresse.toString())?.trim() ??
          '';

  // ---------------------------
  // SMART category inference
  // ---------------------------
  PlaceCategory _inferCategory(dynamic place) {
    if (place is Site) return PlaceCategory.site;
    if (place is Resto) return PlaceCategory.resto;
    if (place is Hotel) return PlaceCategory.hotel;
    if (place is Event) return PlaceCategory.event;
    if (place is Entreprise) return PlaceCategory.entreprise;
    if (place is Shopping) return PlaceCategory.shopping;

    final typeName = place.runtimeType.toString().toLowerCase();
    if (typeName.contains('site')) return PlaceCategory.site;
    if (typeName.contains('resto')) return PlaceCategory.resto;
    if (typeName.contains('hotel')) return PlaceCategory.hotel;
    if (typeName.contains('event')) return PlaceCategory.event;
    if (typeName.contains('entreprise')) return PlaceCategory.entreprise;
    if (typeName.contains('shopping')) return PlaceCategory.shopping;

    return PlaceCategory.site;
  }

  bool _matchesQuery(dynamic p, String q) {
    if (q.isEmpty) return true;

    final hay = [
      _nameOf(p),
      _descOf(p),
      _addressOf(p),
    ].join(' ').toLowerCase();

    return hay.contains(q.toLowerCase());
  }

  bool _matchesCategory(dynamic p) {
    if (_categoryFilter == null) return true;
    return _inferCategory(p) == _categoryFilter;
  }

  // ✅ NOUVEAU : Vérifier si le lieu correspond au filtre de localisation
  bool _matchesLocation(dynamic p) {
    if (_locationFilter == null || _locationFilter!.isEmpty) return true;

    final address = _addressOf(p).toLowerCase();
    final filter = _locationFilter!.toLowerCase();

    return address.contains(filter);
  }

  List<dynamic> _filteredPlaces(List<dynamic> items, String q) {
    return items
        .where((p) =>
    _matchesCategory(p) &&
        _matchesQuery(p, q) &&
        _matchesLocation(p))  // ✅ NOUVEAU filtre
        .toList();
  }

  // ✅ NOUVEAU : Extraire les villes/communes uniques des adresses
  List<String> _extractUniqueLocations(List<dynamic> items) {
    final locations = <String>{};

    for (final item in items) {
      final address = _addressOf(item);
      if (address.isNotEmpty) {
        // Extraire la ville de l'adresse
        // Format typique : "Rue X, Gombe, Kinshasa, Congo"
        final parts = address.split(',');

        if (parts.length >= 2) {
          // Prendre l'avant-dernière partie (commune/ville)
          final city = parts[parts.length - 2].trim();
          if (city.isNotEmpty && city.length > 2) {
            locations.add(city);
          }
        } else if (parts.length == 1) {
          // Si une seule partie, prendre le premier mot
          final words = address.split(' ');
          if (words.isNotEmpty && words.first.length > 2) {
            locations.add(words.first);
          }
        }
      }
    }

    return locations.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final itemsToUse = widget.allItems;

    if (itemsToUse != null) {
      return _buildContent(theme, itemsToUse);
    }

    final allPlacesAsync = ref.watch(allPlacesProvider);

    return allPlacesAsync.when(
      data: (items) => _buildContent(theme, items),
      loading: () => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(theme, []),
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      ),
      error: (e, _) => _buildContent(theme, []),
    );
  }

  Widget _buildContent(ThemeData theme, List<dynamic> items) {
    final q = _searchCtrl.text.trim();
    final places = _filteredPlaces(items, q);
    final bool emptyAll = places.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(theme, items),
            Expanded(
              child: emptyAll
                  ? _emptyState(theme)
                  : ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                children: [
                  ...places.map((p) => _placeTile(context, theme, p)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, List<dynamic> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          // Barre de recherche
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Rechercher',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.trim().isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {});
                },
              ),
              filled: true,
              fillColor: theme.brightness == Brightness.light
                  ? Colors.grey.shade100
                  : Colors.grey.shade800,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Filtre de catégorie
          _categoryDropdown(theme),
          const SizedBox(height: 10),

          // ✅ NOUVEAU : Filtre de localisation
          _locationDropdown(theme, items),
        ],
      ),
    );
  }

  Widget _categoryDropdown(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? Colors.grey.shade100
            : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.25),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PlaceCategory?>(
          isExpanded: true,
          value: _categoryFilter,
          icon: const Icon(Icons.keyboard_arrow_down),
          borderRadius: BorderRadius.circular(14),
          items: [
            const DropdownMenuItem<PlaceCategory?>(
              value: null,
              child: Text('Tous'),
            ),
            DropdownMenuItem(
              value: PlaceCategory.hotel,
              child: Text(_labelOf(PlaceCategory.hotel)),
            ),
            DropdownMenuItem(
              value: PlaceCategory.resto,
              child: Text(_labelOf(PlaceCategory.resto)),
            ),
            DropdownMenuItem(
              value: PlaceCategory.event,
              child: Text(_labelOf(PlaceCategory.event)),
            ),
            DropdownMenuItem(
              value: PlaceCategory.entreprise,
              child: Text(_labelOf(PlaceCategory.entreprise)),
            ),
            DropdownMenuItem(
              value: PlaceCategory.shopping,
              child: Text(_labelOf(PlaceCategory.shopping)),
            ),
            DropdownMenuItem(
              value: PlaceCategory.site,
              child: Text(_labelOf(PlaceCategory.site)),
            ),
          ],
          onChanged: (v) => setState(() => _categoryFilter = v),
        ),
      ),
    );
  }

  // ✅ NOUVEAU : Dropdown pour filtrer par ville/localisation
  Widget _locationDropdown(ThemeData theme, List<dynamic> items) {
    final locations = _extractUniqueLocations(items);

    // Ne rien afficher si aucune localisation
    if (locations.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? Colors.grey.shade100
            : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.25),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: _locationFilter,
          icon: const Icon(Icons.keyboard_arrow_down),
          hint: Row(
            children: const [
              Icon(Icons.location_on, size: 18),
              SizedBox(width: 8),
              Text('Toutes les villes'),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 18),
                  SizedBox(width: 8),
                  Text('Toutes les villes'),
                ],
              ),
            ),
            ...locations.map((loc) => DropdownMenuItem(
              value: loc,
              child: Row(
                children: [
                  const Icon(Icons.location_city, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
          ],
          onChanged: (v) => setState(() => _locationFilter = v),
        ),
      ),
    );
  }

  String _labelOf(PlaceCategory c) {
    switch (c) {
      case PlaceCategory.hotel:
        return 'Hôtels';
      case PlaceCategory.resto:
        return 'Restaurants';
      case PlaceCategory.event:
        return 'Événements';
      case PlaceCategory.site:
        return 'Sites';
      case PlaceCategory.entreprise:
        return 'Business';
      case PlaceCategory.shopping:
        return 'Market';
    }
  }

  IconData _placeIcon(PlaceCategory c) {
    switch (c) {
      case PlaceCategory.hotel:
        return Icons.hotel;
      case PlaceCategory.resto:
        return Icons.restaurant;
      case PlaceCategory.event:
        return Icons.event;
      case PlaceCategory.site:
        return Icons.landscape;
      case PlaceCategory.entreprise:
        return Icons.home_work;
      case PlaceCategory.shopping:
        return Icons.shopping_bag_outlined;
    }
  }

  Widget _placeTile(BuildContext context, ThemeData theme, dynamic place) {
    final name = _nameOf(place);
    final desc = _descOf(place);
    final category = _inferCategory(place);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 56,
            height: 56,
            child: _placeImage(place, theme, category),
          ),
        ),
        title: Text(
          name.isEmpty ? 'Sans nom' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          desc.isEmpty ? _addressOf(place) : desc,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          _placeIcon(category),
          color: theme.colorScheme.primary.withOpacity(0.6),
          size: 20,
        ),
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
  }

  Widget _emptyState(ThemeData theme) {
    final hasQuery = _searchCtrl.text.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.explore_outlined,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'Aucun résultat trouvé' : 'Commencez à rechercher',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Essayez avec d\'autres mots-clés ou filtres.'
                  : 'Découvrez les meilleurs lieux de Kinshasa.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeImage(dynamic place, ThemeData theme, PlaceCategory category) {
    final img = _imageOf(place);

    Widget fallback() => Container(
      color: theme.colorScheme.primary.withOpacity(0.12),
      child: Icon(
        _placeIcon(category),
        color: theme.colorScheme.primary,
      ),
    );

    if (img.isEmpty) return fallback();

    final isNetwork = img.startsWith('http://') || img.startsWith('https://');
    final isAsset = img.startsWith('assets/');

    if (isAsset) {
      return Image.asset(
        img,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }

    if (isNetwork) {
      return Image.network(
        img,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: theme.dividerColor.withOpacity(0.08),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    }

    return fallback();
  }
}