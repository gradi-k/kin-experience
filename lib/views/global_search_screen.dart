// lib/views/global_search_screen.dart
// ✅ VERSION MODIFIÉE avec filtre par ville/localisation

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/categories_controller.dart';
import '../controllers/places_controller.dart';
import '../localization/app_localizations.dart';
import '../models/place.dart';
import 'detail_screen.dart';
import 'widgets/app_network_image.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  final List<Place>? allItems;

  const GlobalSearchScreen({
    super.key,
    this.allItems,
  });

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  /// Clé de catégorie, `null` = toutes.
  String? _categoryFilter;
  String? _locationFilter;  // ✅ NOUVEAU : Filtre par ville/commune

  // Debounce de la saisie : on ne refiltre pas à chaque frappe
  Timer? _debounce;

  // Mémoïsation des localisations extraites (recalculées uniquement
  // quand la liste source change)
  List<Place>? _locationsSource;
  List<String> _cachedLocations = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  // ---------------------------
  // Accès aux champs du lieu
  //
  // Les lieux étaient typés `dynamic` (6 classes distinctes) : il fallait
  // tâtonner sur les noms de champs et deviner la catégorie depuis le
  // runtimeType. Place expose tout ça directement.
  // ---------------------------
  String _nameOf(Place p) => p.nom.trim();

  String _descOf(Place p) => p.description.trim();

  String _imageOf(Place p) => p.photos.isEmpty ? '' : p.photos.first;

  String _addressOf(Place p) => (p.address ?? '').trim();

  bool _matchesQuery(Place p, String q) {
    if (q.isEmpty) return true;
    return p.searchableText.toLowerCase().contains(q.toLowerCase());
  }

  bool _matchesCategory(Place p) {
    if (_categoryFilter == null) return true;
    return p.categoryKey == _categoryFilter;
  }

  // ✅ NOUVEAU : Vérifier si le lieu correspond au filtre de localisation
  bool _matchesLocation(Place p) {
    if (_locationFilter == null || _locationFilter!.isEmpty) return true;

    final address = _addressOf(p).toLowerCase();
    final filter = _locationFilter!.toLowerCase();

    return address.contains(filter);
  }

  List<Place> _filteredPlaces(List<Place> items, String q) {
    return items
        .where((p) =>
    _matchesCategory(p) &&
        _matchesQuery(p, q) &&
        _matchesLocation(p))  // ✅ NOUVEAU filtre
        .toList();
  }

  // ✅ NOUVEAU : Extraire les villes/communes uniques des adresses
  // (mémoïsé : recalcul seulement quand la liste source change)
  List<String> _extractUniqueLocations(List<Place> items) {
    if (identical(items, _locationsSource)) return _cachedLocations;
    _locationsSource = items;
    _cachedLocations = _computeUniqueLocations(items);
    return _cachedLocations;
  }

  List<String> _computeUniqueLocations(List<Place> items) {
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

  Widget _buildContent(ThemeData theme, List<Place> items) {
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
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                itemCount: places.length,
                itemBuilder: (context, index) =>
                    _placeTile(context, theme, places[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, List<Place> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          // Barre de recherche
          TextField(
            controller: _searchCtrl,
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)?.translate('search') ??
                  'Rechercher',
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
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final localeCode = Localizations.localeOf(context).languageCode;

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
          value: _categoryFilter,
          icon: const Icon(Icons.keyboard_arrow_down),
          borderRadius: BorderRadius.circular(14),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Tous'),
            ),
            ...categories.map(
              (c) => DropdownMenuItem<String?>(
                value: c.key,
                child: Text(c.labelFor(localeCode)),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _categoryFilter = v),
        ),
      ),
    );
  }

  // ✅ NOUVEAU : Dropdown pour filtrer par ville/localisation
  Widget _locationDropdown(ThemeData theme, List<Place> items) {
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

  Widget _placeTile(BuildContext context, ThemeData theme, Place place) {
    final name = _nameOf(place);
    final desc = _descOf(place);
    final category = ref.watch(categoryByKeyProvider(place.categoryKey));
    final categoryIcon = category?.icon ?? Icons.place_outlined;

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
            child: _placeImage(place, theme, categoryIcon),
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
          categoryIcon,
          color: theme.colorScheme.primary.withOpacity(0.6),
          size: 20,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DetailScreen(place: place),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    final hasQuery = _searchCtrl.text.trim().isNotEmpty;
    final loc = AppLocalizations.of(context);

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
              hasQuery
                  ? (loc?.translate('no_results_found') ?? 'Aucun résultat trouvé')
                  : (loc?.translate('start_searching') ?? 'Commencez à rechercher'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? (loc?.translate('try_other_keywords') ??
                      'Essayez avec d\'autres mots-clés ou filtres.')
                  : (loc?.translate('discover_kinshasa') ??
                      'Découvrez les meilleurs lieux de Kinshasa.'),
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

  Widget _placeImage(Place place, ThemeData theme, IconData fallbackIcon) {
    // Vignette 56px : décodage plafonné + cache disque
    return AppNetworkImage(
      url: _imageOf(place),
      memCacheWidth: 200,
      fallbackIcon: fallbackIcon,
    );
  }
}