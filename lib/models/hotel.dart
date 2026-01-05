import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle représentant un hôtel.  Cette classe pourrait être étendue
/// ultérieurement pour gérer les services spécifiques (ex. nombre
/// d’étoiles, équipements).  Les champs de base restent identiques aux
/// autres modèles pour faciliter le partage de logique.
class Hotel {
  final String id;
  final String nom;
  final String description;
  final double rating;
  final double latitude;
  final double longitude;
  final List<String> photos;
  final String prixRange;
  final bool isFeatured;

  Hotel({
    required this.id,
    required this.nom,
    required this.description,
    required this.rating,
    required this.latitude,
    required this.longitude,
    required this.photos,
    required this.prixRange,
    required this.isFeatured,
  });

  factory Hotel.fromMap(Map<String, dynamic> data, String documentId) {
    return Hotel(
      id: documentId,
      nom: data['nom'] ?? '',
      description: data['description'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      photos: List<String>.from(data['photos'] ?? []),
      prixRange: data['prixRange'] ?? '',
      isFeatured: data['isFeatured'] ?? false,
    );
  }

  factory Hotel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Hotel.fromMap(data, doc.id);
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
    };
  }
}