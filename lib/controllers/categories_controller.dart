import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_config.dart';
import '../services/categories_service.dart';

final categoriesServiceProvider = Provider<CategoriesService>((ref) {
  return CategoriesService();
});

/// Catégories visibles dans l'app publique, triées par `order`.
///
/// Pas d'autoDispose : ce stream est la colonne vertébrale de la home, des
/// filtres et de la navigation. Le garder en vie évite un re-fetch (et un
/// écran de chargement) à chaque aller-retour entre écrans.
final categoriesProvider = StreamProvider<List<CategoryConfig>>((ref) {
  return ref.watch(categoriesServiceProvider).watchEnabled();
});

/// Toutes les catégories, désactivées comprises. Réservé à l'admin.
final allCategoriesProvider = StreamProvider.autoDispose<List<CategoryConfig>>((ref) {
  return ref.watch(categoriesServiceProvider).watchAll();
});

/// Une catégorie par sa clé, `null` si inconnue ou désactivée.
///
/// Se sert du cache de [categoriesProvider] : aucune lecture Firestore
/// supplémentaire.
final categoryByKeyProvider = Provider.family<CategoryConfig?, String>((ref, key) {
  final categories = ref.watch(categoriesProvider).value ?? const [];
  for (final c in categories) {
    if (c.key == key) return c;
  }
  return null;
});

/// Nombre de lieux d'une catégorie, pour l'écran admin.
final categoryPlaceCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, key) {
  return ref.watch(categoriesServiceProvider).countPlaces(key);
});
