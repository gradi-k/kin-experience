import 'model_helpers.dart';

class Event {
  final String id;
  final String nom;
  final String description;
  final double rating;
  final double latitude;
  final double longitude;
  final List<String> photos;
  final String prixRange;
  final bool isFeatured;

  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? tiktokUrl;
  final List<String> amenities;
  final String? schedule;
  final int? reviewCount;
  final double? distanceKm;

  const Event({
    required this.id,
    required this.nom,
    required this.description,
    required this.rating,
    required this.latitude,
    required this.longitude,
    required this.photos,
    required this.prixRange,
    required this.isFeatured,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.facebookUrl,
    this.instagramUrl,
    this.tiktokUrl,
    this.amenities = const [],
    this.schedule,
    this.reviewCount,
    this.distanceKm,
  });

  factory Event.fromMap(Map<String, dynamic> map, String id) {
    return Event(
      id: id,
      nom: (map['nom'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      rating: ModelHelpers.parseDouble(map['rating']),
      latitude: ModelHelpers.parseDouble(map['latitude']),
      longitude: ModelHelpers.parseDouble(map['longitude']),
      photos: ModelHelpers.parsePhotos(map['photos']),
      prixRange: (map['prixRange'] ?? '').toString(),
      isFeatured: ModelHelpers.parseBool(map['isFeatured']),
      address: map['address']?.toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      website: map['website']?.toString(),
      facebookUrl: map['facebookUrl']?.toString(),
      instagramUrl: map['instagramUrl']?.toString(),
      tiktokUrl: map['tiktokUrl']?.toString(),
      amenities: ModelHelpers.parseStringList(map['amenities']),
      schedule: map['schedule']?.toString(),
      reviewCount: map['reviewCount'] != null ? ModelHelpers.parseInt(map['reviewCount']) : null,
      distanceKm: map['distanceKm'] != null ? ModelHelpers.parseDouble(map['distanceKm']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'description': description,
      'rating': rating,
      'latitude': latitude,
      'longitude': longitude,
      'photos': photos,
      'prixRange': prixRange,
      'isFeatured': isFeatured,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'facebookUrl': facebookUrl,
      'instagramUrl': instagramUrl,
      'tiktokUrl': tiktokUrl,
      'amenities': amenities,
      'schedule': schedule,
      'reviewCount': reviewCount,
      'distanceKm': distanceKm,
    };
  }
}