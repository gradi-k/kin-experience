// lib/services/geocoding_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

/// Service de géocodage utilisant l'API Nominatim (OpenStreetMap)
/// Gratuit, sans clé API nécessaire
class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'CityGuideApp/1.0';

  /// Recherche d'adresses avec autocomplétion
  /// Retourne une liste de suggestions d'adresses
  Future<List<AddressSuggestion>> searchAddresses(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final url = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'limit': '5',
        'countrycodes': 'cd', // Congo (Kinshasa)
      });

      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => AddressSuggestion.fromJson(item)).toList();
      }

      return [];
    } catch (e) {
      print('Error searching addresses: $e');
      return [];
    }
  }

  /// Géocode une adresse complète
  /// Retourne les coordonnées GPS
  Future<GeocodingResult?> geocodeAddress(String address) async {
    if (address.trim().isEmpty) return null;

    try {
      final url = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'q': address,
        'format': 'json',
        'addressdetails': '1',
        'limit': '1',
      });

      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          return GeocodingResult.fromJson(data.first);
        }
      }

      return null;
    } catch (e) {
      print('Error geocoding address: $e');
      return null;
    }
  }

  /// Géocode inverse : obtient l'adresse depuis des coordonnées
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final url = Uri.parse('$_baseUrl/reverse').replace(queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'format': 'json',
        'addressdetails': '1',
      });

      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] as String?;
      }

      return null;
    } catch (e) {
      print('Error reverse geocoding: $e');
      return null;
    }
  }

  /// Obtient la position actuelle de l'appareil
  Future<Position?> getCurrentPosition() async {
    try {
      // Vérifier les permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return null;
      }

      // Obtenir la position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }
}

/// Modèle pour une suggestion d'adresse
class AddressSuggestion {
  final String displayName;
  final double latitude;
  final double longitude;
  final String? city;
  final String? road;
  final String? suburb;

  /// Provenance : 'zone' (commune locale), 'place' (lieu en base), 'osm'.
  final String source;

  const AddressSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.city,
    this.road,
    this.suburb,
    this.source = 'osm',
  });

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>?;

    return AddressSuggestion(
      displayName: json['display_name'] as String,
      latitude: double.parse(json['lat'].toString()),
      longitude: double.parse(json['lon'].toString()),
      city: address?['city']?.toString() ??
          address?['town']?.toString() ??
          address?['village']?.toString(),
      road: address?['road']?.toString(),
      suburb: address?['suburb']?.toString(),
    );
  }

  String get shortAddress {
    final parts = <String>[];
    if (road != null) parts.add(road!);
    if (suburb != null) parts.add(suburb!);
    if (city != null) parts.add(city!);
    return parts.isEmpty ? displayName : parts.join(', ');
  }
}

/// Modèle pour un résultat de géocodage
class GeocodingResult {
  final double latitude;
  final double longitude;
  final String displayName;

  const GeocodingResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    return GeocodingResult(
      latitude: double.parse(json['lat'].toString()),
      longitude: double.parse(json['lon'].toString()),
      displayName: json['display_name'] as String,
    );
  }
}