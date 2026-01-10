import 'package:cloud_firestore/cloud_firestore.dart';
// On utilise flutter_riverpod pour bénéficier de StateNotifier et StateNotifierProvider.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/site.dart';
import '../models/resto.dart';
import '../models/hotel.dart';
import '../models/event.dart';
import '../models/entreprise.dart';
import '../data/fake_data.dart';

/// Enumération des catégories de lieux.  Cette énumération sert de
/// paramètre lors du chargement afin d’éviter les erreurs de type.
enum PlaceCategory { site, resto, hotel, event, entreprise }

/// Extension pour convertir le [PlaceCategory] en identifiant de
/// collection Firestore.
extension PlaceCategoryExtension on PlaceCategory {
  String get collectionName {
    switch (this) {
      case PlaceCategory.site:
        return 'sites';
      case PlaceCategory.resto:
        return 'restos';
      case PlaceCategory.hotel:
        return 'hotels';
      case PlaceCategory.event:
        return 'events';
      case PlaceCategory.entreprise:
        return 'entreprises';
    }
  }
}

/// Contrôleur Riverpod gérant le chargement et l’état des listes de lieux.
/// Il retourne des [AsyncValue] afin de représenter les états de chargement
/// (loading, data ou error).  On peut appeler [load] avec une
/// catégorie afin de récupérer les données correspondantes.
class PlacesController extends StateNotifier<AsyncValue<List<dynamic>>> {
  PlacesController() : super(const AsyncLoading());

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Charge la liste des lieux en fonction de la catégorie.
  ///
  /// Cette méthode interroge d’abord Firestore.  Si aucune donnée n’est
  /// trouvée pour la collection, des données factices issues de
  /// `fake_data.dart` sont insérées puis retournées.  Cela permet à
  /// l’application de démarrer avec un contenu dynamique tout en
  /// préservant la possibilité de mettre à jour les enregistrements.
  Future<void> load(PlaceCategory category) async {
    state = const AsyncLoading();
    try {
      final collection = _firestore.collection(category.collectionName);
      // Récupère la liste des documents
      QuerySnapshot snapshot = await collection.get();
      // Si la collection est vide, insérer les données factices
      if (snapshot.docs.isEmpty) {
        final sampleList = _getSampleList(category);
        for (final item in sampleList) {
          await collection.add(item.toMap());
        }
        snapshot = await collection.get();
      }
      // Transforme les documents en instances de modèles
      final results = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        switch (category) {
          case PlaceCategory.site:
            return Site.fromMap(data, doc.id);
          case PlaceCategory.resto:
            return Resto.fromMap(data, doc.id);
          case PlaceCategory.hotel:
            return Hotel.fromMap(data, doc.id);
          case PlaceCategory.event:
            return Event.fromMap(data, doc.id);
          case PlaceCategory.entreprise:
            return Entreprise.fromMap(data, doc.id);
        }
      }).toList();
      state = AsyncValue.data(results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Retourne la liste d’objets factices correspondant à la catégorie.
  /// Cette fonction est utilisée lors du premier démarrage pour
  /// alimenter Firestore avec des valeurs par défaut.  Les listes sont
  /// définies dans `fake_data.dart`.
  List<dynamic> _getSampleList(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.site:
        return fakeSites;
      case PlaceCategory.resto:
        return fakeRestos;
      case PlaceCategory.hotel:
        return fakeHotels;
      case PlaceCategory.event:
        return fakeEvents;
      case PlaceCategory.entreprise:
        return fakeEntreprises;
    }
  }
}

/// Fournisseur global exposant le [PlacesController].  Ce provider peut
/// ensuite être utilisé dans les vues pour observer l’état (via
/// [AsyncValue]) et déclencher le chargement.
final placesControllerProvider =
    StateNotifierProvider<PlacesController, AsyncValue<List<dynamic>>>(
  (ref) => PlacesController(),
);