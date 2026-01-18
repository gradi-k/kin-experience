import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/place_enums.dart';
import '../repositories/places_repository.dart';

/// Provider du repository (adapte si tu l’as déjà ailleurs)
final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  return PlacesRepository();
});

/// Contrôleur Riverpod: charge une liste de lieux par catégorie via Firebase (Repository).
class PlacesController extends StateNotifier<AsyncValue<List<dynamic>>> {
  PlacesController(this._repo) : super(const AsyncLoading());

  final PlacesRepository _repo;

  Future<void> load(PlaceCategory category) async {
    state = const AsyncLoading();
    try {
      final items = await _repo.fetchPlaces(category);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider du controller
final placesControllerProvider =
StateNotifierProvider<PlacesController, AsyncValue<List<dynamic>>>((ref) {
  final repo = ref.watch(placesRepositoryProvider);
  return PlacesController(repo);
});
