import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position> getCurrentPosition() async {
    // 1) Service GPS activé ?
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Activez la localisation (GPS) dans les réglages.");
    }

    // 2) Permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception("Permission localisation refusée.");
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Permission refusée définitivement. Activez-la dans les réglages.");
    }

    // 3) Position (équilibré en perf)
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  }

  double distanceMeters({
    required double userLat,
    required double userLng,
    required double placeLat,
    required double placeLng,
  }) {
    return Geolocator.distanceBetween(userLat, userLng, placeLat, placeLng);
  }

  String formatDistance(double meters) {
    if (meters < 1000) return "${meters.round()} m";
    final km = meters / 1000;
    return "${km.toStringAsFixed(1)} km";
  }
}
