// lib/controllers/places_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/category_config.dart';
import '../models/place.dart';
import '../services/places_repository.dart';
import 'categories_controller.dart';

// ============================================================
// REPOSITORY PROVIDER
// ============================================================
final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  return PlacesRepository();
});

/// Limite d'éléments par section de la home.
const int kHomeSectionLimit = 30;

/// Limite d'éléments pour les écrans de liste par catégorie.
const int kCategoryListLimit = 200;

// ============================================================
// STREAM PROVIDERS
// ============================================================

/// Lieux d'une catégorie, par clé. Remplace les 6 providers typés
/// (sitesProvider, hotelsProvider, ...).
final placesByCategoryProvider =
    StreamProvider.autoDispose.family<List<Place>, String>((ref, categoryKey) {
  final repo = ref.watch(placesRepositoryProvider);
  return repo.watchByCategory(categoryKey, limit: kCategoryListLimit);
});

/// Version limitée pour les sections de la home. Séparée de
/// [placesByCategoryProvider] pour que la home ne charge pas 200 lieux par
/// catégorie.
final homePlacesByCategoryProvider =
    StreamProvider.family<List<Place>, String>((ref, categoryKey) {
  final repo = ref.watch(placesRepositoryProvider);
  return repo.watchByCategory(categoryKey, limit: kHomeSectionLimit);
});

/// Tous les lieux (recherche globale, carte).
///
/// Un seul listener depuis la fusion des collections — l'ancienne version en
/// ouvrait six et les recombinait à la main.
final allPlacesProvider = StreamProvider.autoDispose<List<Place>>((ref) {
  final repo = ref.watch(placesRepositoryProvider);
  return repo.watchAllPlaces();
});

/// Lieux mis en avant, filtrés côté serveur.
final featuredPlacesProvider = StreamProvider<List<Place>>((ref) {
  final repo = ref.watch(placesRepositoryProvider);
  return repo.watchFeaturedPlaces();
});

/// Un lieu par son id, en temps réel.
final placeByIdProvider =
    StreamProvider.autoDispose.family<Place?, String>((ref, id) {
  final repo = ref.watch(placesRepositoryProvider);
  return repo.watchById(id);
});

// ============================================================
// SECTIONS DE LA HOME
// ============================================================

/// Une section de la home = une catégorie + ses lieux.
class HomeSection {
  final CategoryConfig category;
  final List<Place> items;

  const HomeSection({required this.category, required this.items});

  String get key => category.key;
}

/// Sections de la home, construites depuis les catégories Firestore.
///
/// Le nombre de sections suit la config : ajouter une catégorie dans l'admin
/// ajoute sa section ici, sans toucher au code.
///
/// Une catégorie encore en chargement ou en erreur est simplement omise plutôt
/// que de bloquer toute la home : une catégorie vide ou cassée ne doit pas
/// masquer les autres.
final homeSectionsProvider = Provider<AsyncValue<List<HomeSection>>>((ref) {
  final categoriesAsync = ref.watch(categoriesProvider);

  return categoriesAsync.whenData((categories) {
    final sections = <HomeSection>[];
    for (final category in categories) {
      final items = ref.watch(homePlacesByCategoryProvider(category.key));
      final value = items.value;
      if (value == null || value.isEmpty) continue;
      sections.add(HomeSection(category: category, items: value));
    }
    return sections;
  });
});

/// Vrai tant qu'au moins une section n'a pas répondu — permet à la home
/// d'afficher ses squelettes sans attendre la catégorie la plus lente.
final homeSectionsLoadingProvider = Provider<bool>((ref) {
  final categories = ref.watch(categoriesProvider).value;
  if (categories == null) return true;
  for (final c in categories) {
    if (ref.watch(homePlacesByCategoryProvider(c.key)).isLoading) return true;
  }
  return false;
});

// ============================================================
// RECHERCHE
// ============================================================

class SearchState {
  final String query;

  /// Clé de catégorie, `null` = toutes.
  final String? categoryFilter;
  final List<Place> results;
  final bool isLoading;

  const SearchState({
    this.query = '',
    this.categoryFilter,
    this.results = const [],
    this.isLoading = false,
  });

  SearchState copyWith({
    String? query,
    String? categoryFilter,
    List<Place>? results,
    bool? isLoading,
    bool clearCategoryFilter = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      categoryFilter:
          clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;

  SearchNotifier(this._ref) : super(const SearchState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
    _performSearch();
  }

  void setCategoryFilter(String? categoryKey) {
    state = categoryKey == null
        ? state.copyWith(clearCategoryFilter: true)
        : state.copyWith(categoryFilter: categoryKey);
    _performSearch();
  }

  void _performSearch() {
    final allPlaces = _ref.read(allPlacesProvider).value ?? const <Place>[];
    final query = state.query.toLowerCase().trim();
    final categoryFilter = state.categoryFilter;

    if (query.isEmpty && categoryFilter == null) {
      state = state.copyWith(results: allPlaces);
      return;
    }

    final results = allPlaces.where((place) {
      if (categoryFilter != null && place.categoryKey != categoryFilter) {
        return false;
      }
      if (query.isNotEmpty &&
          !place.searchableText.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();

    state = state.copyWith(results: results);
  }

  void clear() => state = const SearchState();
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});
