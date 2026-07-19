// lib/services/address_suggestions_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cityguide/data/kinshasa_zones.dart';
import 'package:cityguide/services/geocoding_service.dart';

/// Fusionne trois sources de suggestions d'adresses :
/// 1. communes de Kinshasa (liste locale, hors-ligne),
/// 2. lieux déjà publiés dans `places` (préfixe sur `nom`),
/// 3. Nominatim (OpenStreetMap).
///
/// Une source qui échoue est ignorée : le sélecteur d'adresse doit rester
/// utilisable même sans réseau (les communes suffisent alors).
class AddressSuggestionsService {
  final GeocodingService _geocoding;
  final Future<List<AddressSuggestion>> Function(String query) _placesSearch;

  AddressSuggestionsService({
    GeocodingService? geocoding,
    Future<List<AddressSuggestion>> Function(String query)? placesSearch,
  })  : _geocoding = geocoding ?? GeocodingService(),
        _placesSearch = placesSearch ?? _defaultPlacesSearch;

  Future<List<AddressSuggestion>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final zones = _searchZones(q);
    final results = await Future.wait([
      _safe(() => _placesSearch(q)),
      _safe(() => _geocoding.searchAddresses(q)),
    ]);

    return [...zones, ...results[0].take(4), ...results[1].take(5)]
        .take(12)
        .toList();
  }

  List<AddressSuggestion> _searchZones(String q) {
    final lower = q.toLowerCase();
    return kinshasaZones
        .where((z) => z.nom.toLowerCase().contains(lower))
        .take(3)
        .map((z) => AddressSuggestion(
              displayName: '${z.nom}, Kinshasa',
              latitude: z.latitude,
              longitude: z.longitude,
              city: 'Kinshasa',
              suburb: z.nom,
              source: 'zone',
            ))
        .toList();
  }

  /// Recherche par préfixe sur le nom des lieux publiés. La casse compte pour
  /// Firestore : on tente la requête telle quelle et capitalisée.
  static Future<List<AddressSuggestion>> _defaultPlacesSearch(
      String query) async {
    final cap = query[0].toUpperCase() + query.substring(1);
    final prefixes = {query, cap};

    final snapshots = await Future.wait(prefixes.map((p) =>
        FirebaseFirestore.instance
            .collection('places')
            .where('isDraft', isEqualTo: false)
            .where('nom', isGreaterThanOrEqualTo: p)
            .where('nom', isLessThan: '$p')
            .limit(4)
            .get()));

    final seen = <String>{};
    final out = <AddressSuggestion>[];
    for (final snap in snapshots) {
      for (final d in snap.docs) {
        if (!seen.add(d.id)) continue;
        final data = d.data();
        final lat = (data['latitude'] as num?)?.toDouble() ?? 0;
        final lng = (data['longitude'] as num?)?.toDouble() ?? 0;
        if (lat == 0 && lng == 0) continue;
        final address = (data['address'] ?? '').toString().trim();
        out.add(AddressSuggestion(
          displayName:
              address.isEmpty ? '${data['nom']}' : '${data['nom']} — $address',
          latitude: lat,
          longitude: lng,
          source: 'place',
        ));
      }
    }
    return out;
  }

  Future<List<AddressSuggestion>> _safe(
      Future<List<AddressSuggestion>> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return [];
    }
  }
}
