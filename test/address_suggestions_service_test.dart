import 'package:flutter_test/flutter_test.dart';
import 'package:cityguide/services/address_suggestions_service.dart';
import 'package:cityguide/services/geocoding_service.dart';

class _FakeGeocoding extends GeocodingService {
  final List<AddressSuggestion> results;
  final bool shouldThrow;
  _FakeGeocoding(this.results, {this.shouldThrow = false});

  @override
  Future<List<AddressSuggestion>> searchAddresses(String query) async {
    if (shouldThrow) throw Exception('réseau');
    return results;
  }
}

void main() {
  test('les communes matchent par sous-chaîne insensible à la casse', () async {
    final svc = AddressSuggestionsService(
      geocoding: _FakeGeocoding(const []),
      placesSearch: (_) async => const [],
    );
    final out = await svc.search('gom');
    expect(out, isNotEmpty);
    expect(out.first.displayName, contains('Gombe'));
    expect(out.first.source, 'zone');
  });

  test('fusion : zones puis lieux puis osm', () async {
    final svc = AddressSuggestionsService(
      geocoding: _FakeGeocoding(const [
        AddressSuggestion(displayName: 'Gombe OSM', latitude: 1, longitude: 2),
      ]),
      placesSearch: (_) async => const [
        AddressSuggestion(
          displayName: 'Restaurant Gombe Grill',
          latitude: 3,
          longitude: 4,
          source: 'place',
        ),
      ],
    );
    final out = await svc.search('gombe');
    expect(out.map((s) => s.source).toList(), ['zone', 'place', 'osm']);
  });

  test('une source qui échoue est ignorée', () async {
    final svc = AddressSuggestionsService(
      geocoding: _FakeGeocoding(const [], shouldThrow: true),
      placesSearch: (_) async => throw Exception('firestore'),
    );
    final out = await svc.search('gombe');
    expect(out, isNotEmpty); // la zone Gombe reste
    expect(out.every((s) => s.source == 'zone'), isTrue);
  });

  test('requête vide => liste vide', () async {
    final svc = AddressSuggestionsService(
      geocoding: _FakeGeocoding(const []),
      placesSearch: (_) async => const [],
    );
    expect(await svc.search('   '), isEmpty);
  });
}
