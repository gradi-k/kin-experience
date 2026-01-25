// lib/controllers/places_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/places_repository.dart';
import '../models/site.dart';
import '../models/resto.dart';
import '../models/hotel.dart';
import '../models/event.dart';
import '../models/entreprise.dart';
import '../models/shopping.dart';
import '../models/place_enums.dart';

// ============================================================
// REPOSITORY PROVIDER
// ============================================================
final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  return PlacesRepository();
});

// ============================================================
// STREAM PROVIDERS (données temps réel)
// ============================================================

/// Provider pour les sites
final sitesProvider = StreamProvider<List<Site>>((ref) {
  final repo = ref.watch(placesRepositoryProvider);
  return repo.watchSites();
});

/// Provider pour les restaurants
final restosProvider = StreamProvider<List<Resto>>((ref) {
  final repo = ref.watch(placesRepositoryProvider);
  return repo.watchRestos();
});

/// Provider pour les hôtels
final hotelsProvider = StreamProvider<List<Hotel>>((ref) {
  final repo = ref.watch(placesRepositoryProvider);
  return repo.watchHotels();
});

/// Provider pour les événements
final eventsProvider = StreamProvider<List<Event>>((ref) {
  final repo = ref.watch(placesRepositoryProvider);
  return repo.watchEvents();
});

/// Provider pour les entreprises
final entreprisesProvider = StreamProvider<List<Entreprise>>((ref) {
  final repo = ref.watch(placesRepositoryProvider);
  return repo.watchEntreprises();
});

/// Provider pour les shoppings
final shoppingsProvider = StreamProvider<List<Shopping>>((ref) {
  final repo = ref.watch(placesRepositoryProvider);
  return repo.watchShoppings();
});

// ============================================================
// COMBINED PROVIDERS
// ============================================================

/// Provider pour tous les éléments combinés (pour la recherche globale)
final allPlacesProvider = StreamProvider<List<dynamic>>((ref) {
  final repo = ref.watch(placesRepositoryProvider);
  return repo.watchAllPlaces();
});

/// Provider pour les éléments mis en avant (featured)
final featuredPlacesProvider = StreamProvider<List<dynamic>>((ref) {
  final repo = ref.watch(placesRepositoryProvider);
  return repo.watchFeaturedPlaces();
});

// ============================================================
// CATEGORY-SPECIFIC PROVIDER (avec paramètre)
// ============================================================

/// Provider famille pour récupérer les données par catégorie
final placesByCategoryProvider = StreamProvider.family<List<dynamic>, PlaceCategory>((ref, category) {
  final repo = ref.watch(placesRepositoryProvider);
  return repo.watchByCategory(category);
});

// ============================================================
// SECTIONS PROVIDER (pour la home page)
// ============================================================

/// Structure pour une section de la home page
class HomeSection {
  final String key;
  final String titleKey;
  final List<dynamic> items;
  final PlaceCategory category;

  const HomeSection({
    required this.key,
    required this.titleKey,
    required this.items,
    required this.category,
  });
}

/// Provider pour les sections de la home page
final homeSectionsProvider = Provider<AsyncValue<List<HomeSection>>>((ref) {
  final sites = ref.watch(sitesProvider);
  final restos = ref.watch(restosProvider);
  final hotels = ref.watch(hotelsProvider);
  final events = ref.watch(eventsProvider);
  final entreprises = ref.watch(entreprisesProvider);
  final shoppings = ref.watch(shoppingsProvider);

  // Si l'un des providers est en loading, retourner loading
  if (sites.isLoading || restos.isLoading || hotels.isLoading ||
      events.isLoading || entreprises.isLoading || shoppings.isLoading) {
    return const AsyncValue.loading();
  }

  // Si erreur
  if (sites.hasError) return AsyncValue.error(sites.error!, sites.stackTrace!);
  if (restos.hasError) return AsyncValue.error(restos.error!, restos.stackTrace!);
  if (hotels.hasError) return AsyncValue.error(hotels.error!, hotels.stackTrace!);
  if (events.hasError) return AsyncValue.error(events.error!, events.stackTrace!);
  if (entreprises.hasError) return AsyncValue.error(entreprises.error!, entreprises.stackTrace!);
  if (shoppings.hasError) return AsyncValue.error(shoppings.error!, shoppings.stackTrace!);

  // Construire les sections
  final sections = <HomeSection>[
    HomeSection(
      key: 'sites',
      titleKey: 'sites_label',
      items: sites.value ?? [],
      category: PlaceCategory.site,
    ),
    HomeSection(
      key: 'restos',
      titleKey: 'restos_label',
      items: restos.value ?? [],
      category: PlaceCategory.resto,
    ),
    HomeSection(
      key: 'hotels',
      titleKey: 'hotels_label',
      items: hotels.value ?? [],
      category: PlaceCategory.hotel,
    ),
    HomeSection(
      key: 'events',
      titleKey: 'events_label',
      items: events.value ?? [],
      category: PlaceCategory.event,
    ),
    HomeSection(
      key: 'entreprises',
      titleKey: 'entreprises_label',
      items: entreprises.value ?? [],
      category: PlaceCategory.entreprise,
    ),
    HomeSection(
      key: 'shop',
      titleKey: 'Market',
      items: shoppings.value ?? [],
      category: PlaceCategory.shopping,
    ),
  ];

  return AsyncValue.data(sections);
});

// ============================================================
// CATEGORY ICONS PROVIDER (pour la navigation rapide)
// ============================================================

class CategoryIconData {
  final String labelKey;
  final dynamic icon; // IconData
  final List<dynamic> items;
  final PlaceCategory category;

  const CategoryIconData({
    required this.labelKey,
    required this.icon,
    required this.items,
    required this.category,
  });
}

// ============================================================
// SEARCH PROVIDER
// ============================================================

/// État de recherche
class SearchState {
  final String query;
  final PlaceCategory? categoryFilter;
  final List<dynamic> results;
  final bool isLoading;

  const SearchState({
    this.query = '',
    this.categoryFilter,
    this.results = const [],
    this.isLoading = false,
  });

  SearchState copyWith({
    String? query,
    PlaceCategory? categoryFilter,
    List<dynamic>? results,
    bool? isLoading,
    bool clearCategoryFilter = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      categoryFilter: clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier pour la recherche
class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;

  SearchNotifier(this._ref) : super(const SearchState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
    _performSearch();
  }

  void setCategoryFilter(PlaceCategory? category) {
    if (category == null) {
      state = state.copyWith(clearCategoryFilter: true);
    } else {
      state = state.copyWith(categoryFilter: category);
    }
    _performSearch();
  }

  void _performSearch() {
    final allPlacesAsync = _ref.read(allPlacesProvider);
    final allPlaces = allPlacesAsync.whenOrNull(data: (data) => data) ?? [];
    final query = state.query.toLowerCase().trim();
    final categoryFilter = state.categoryFilter;

    if (query.isEmpty && categoryFilter == null) {
      state = state.copyWith(results: allPlaces);
      return;
    }

    final results = allPlaces.where((place) {
      // Filtre par catégorie
      if (categoryFilter != null) {
        if (!_matchesCategory(place, categoryFilter)) return false;
      }

      // Filtre par query
      if (query.isNotEmpty) {
        final searchable = _getSearchableText(place).toLowerCase();
        if (!searchable.contains(query)) return false;
      }

      return true;
    }).toList();

    state = state.copyWith(results: results);
  }

  bool _matchesCategory(dynamic place, PlaceCategory category) {
    switch (category) {
      case PlaceCategory.site:
        return place is Site;
      case PlaceCategory.resto:
        return place is Resto;
      case PlaceCategory.hotel:
        return place is Hotel;
      case PlaceCategory.event:
        return place is Event;
      case PlaceCategory.entreprise:
        return place is Entreprise;
      case PlaceCategory.shopping:
        return place is Shopping;
    }
  }

  String _getSearchableText(dynamic place) {
    try {
      final parts = <String>[];
      if (place.nom != null) parts.add(place.nom.toString());
      if (place.description != null) parts.add(place.description.toString());
      if (place.address != null) parts.add(place.address.toString());
      return parts.join(' ');
    } catch (_) {
      return '';
    }
  }

  void clear() {
    state = const SearchState();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});

// ============================================================
// UTILITY FUNCTIONS
// ============================================================

/// Détermine la catégorie d'un place dynamique
PlaceCategory? inferCategory(dynamic place) {
  if (place is Site) return PlaceCategory.site;
  if (place is Resto) return PlaceCategory.resto;
  if (place is Hotel) return PlaceCategory.hotel;
  if (place is Event) return PlaceCategory.event;
  if (place is Entreprise) return PlaceCategory.entreprise;
  if (place is Shopping) return PlaceCategory.shopping;
  return null;
}

/// Crée une map place + category pour la navigation
Map<String, dynamic> placeWithCategory(dynamic place) {
  return {
    'place': place,
    'category': inferCategory(place),
  };
}