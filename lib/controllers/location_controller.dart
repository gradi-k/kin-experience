import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final userPositionProvider = FutureProvider<Position>((ref) async {
  final service = ref.read(locationServiceProvider);
  return service.getCurrentPosition();
});

/// ✅ Ville de l'utilisateur (ex: Kinshasa, Goma, Lubumbashi…)
final userCityProvider = FutureProvider<String>((ref) async {
  final pos = await ref.watch(userPositionProvider.future);

  try {
    final placemarks = await placemarkFromCoordinates(
      pos.latitude,
      pos.longitude,
    );

    if (placemarks.isEmpty) return "Votre ville";

    final place = placemarks.first;

    final city = place.locality?.trim();
    final admin = place.subAdministrativeArea?.trim();
    final country = place.country?.trim();

    return (city != null && city.isNotEmpty)
        ? city
        : (admin != null && admin.isNotEmpty)
        ? admin
        : (country != null && country.isNotEmpty)
        ? country
        : "Votre ville";
  } catch (_) {
    return "Votre ville";
  }
});

/// ✅ Ville + Commune (ex: "Kinshasa, Gombe")
final userCityCommuneProvider = FutureProvider<String>((ref) async {
  final pos = await ref.watch(userPositionProvider.future);

  try {
    final placemarks = await placemarkFromCoordinates(
      pos.latitude,
      pos.longitude,
    );

    if (placemarks.isEmpty) return "Kinshasa";

    final place = placemarks.first;

    final city = (place.locality ?? place.subAdministrativeArea ?? "")
        .trim();

    // ✅ Commune (souvent subLocality)
    final commune = (place.subLocality ??
        place.subAdministrativeArea ??
        place.administrativeArea ??
        "")
        .trim();

    if (city.isEmpty) return "Kinshasa";

    // si commune existe et différente
    if (commune.isNotEmpty && commune.toLowerCase() != city.toLowerCase()) {
      return "$city, $commune";
    }

    return city;
  } catch (_) {
    return "Kinshasa";
  }
});

