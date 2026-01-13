enum PlaceCategory {
  site,
  resto,
  hotel,
  event,
  entreprise,
  shopping,
}

extension PlaceCategoryX on PlaceCategory {
  String get key {
    switch (this) {
      case PlaceCategory.site:
        return 'site';
      case PlaceCategory.resto:
        return 'resto';
      case PlaceCategory.hotel:
        return 'hotel';
      case PlaceCategory.event:
        return 'event';
      case PlaceCategory.entreprise:
        return 'entreprise';
      case PlaceCategory.shopping:
        return 'shopping';
    }
  }

  static PlaceCategory fromKey(String value) {
    switch (value) {
      case 'site':
        return PlaceCategory.site;
      case 'resto':
        return PlaceCategory.resto;
      case 'hotel':
        return PlaceCategory.hotel;
      case 'event':
        return PlaceCategory.event;
      case 'entreprise':
        return PlaceCategory.entreprise;
      case 'shopping':
        return PlaceCategory.shopping;
      default:
        return PlaceCategory.site;
    }
  }
}
