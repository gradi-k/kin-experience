import 'package:flutter/material.dart';
import '../models/place_enums.dart';

/// Ne pas re-déclarer `collectionName` ici.
/// Sinon tu auras: ambiguous_extension_member_access.
extension PlaceCategoryUiExt on PlaceCategory {
  String get label => PlaceCategoryX(this).label;
  IconData get icon => PlaceCategoryX(this).icon;

  // Alias utile si certaines pages utilisent "title"
  String get title => label;
}

