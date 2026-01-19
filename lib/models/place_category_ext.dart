import 'place_enums.dart';

extension PlaceCategoryExt on PlaceCategory {
  String get collectionName {
    switch (this) {
      case PlaceCategory.site:
        return 'sites';
      case PlaceCategory.hotel:
        return 'hotels';
      case PlaceCategory.resto:
        return 'restos';
      case PlaceCategory.event:
        return 'events';
      case PlaceCategory.entreprise:
        return 'entreprises';
      case PlaceCategory.shopping:
        return 'shoppings';
    }
  }
}