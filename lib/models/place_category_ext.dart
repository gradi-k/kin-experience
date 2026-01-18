import 'place_enums.dart';

extension PlaceCategoryX on PlaceCategory {
  /// Nom exact des collections Firestore
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
      case PlaceCategory.shopping:
        return 'shopping';
    }
  }
}
