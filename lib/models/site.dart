class Site {
  final String id;
  final String nom;
  final String description;
  final double rating;
  final double latitude;
  final double longitude;
  final List<String> photos;
  final String prixRange;
  final bool isFeatured;

  // New fields (optional)
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? tiktokUrl;
  final List<String> amenities;
  final String? schedule;
  final int reviewCount;
  final double distanceKm;

  Site({
    required this.id,
    required this.nom,
    required this.description,
    required this.rating,
    required this.latitude,
    required this.longitude,
    required this.photos,
    required this.prixRange,
    this.isFeatured = false,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.facebookUrl,
    this.instagramUrl,
    this.tiktokUrl,
    this.amenities = const [],
    this.schedule,
    this.reviewCount = 0,
    this.distanceKm = 0,
  });

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

  static Site fromMap(Map<String, dynamic> map, String id) {
    return Site(
      id: id,
      nom: (map['nom'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      photos: (map['photos'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      prixRange: (map['prixRange'] ?? '') as String,
      isFeatured: (map['isFeatured'] as bool?) ?? false,
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      website: map['website'] as String?,
      facebookUrl: map['facebookUrl'] as String?,
      instagramUrl: map['instagramUrl'] as String?,
      tiktokUrl: map['tiktokUrl'] as String?,
      amenities: (map['amenities'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      schedule: map['schedule'] as String?,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
