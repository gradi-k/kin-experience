import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle représentant un événement (concert, exposition, etc.).  Des
/// champs supplémentaires peuvent être ajoutés pour les dates et
/// horaires, mais pour rester cohérent avec le schéma initial on ne
/// retient que les informations de base.  
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

  Event({
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

  factory Event.fromMap(Map<String, dynamic> data, String documentId) {
    return Event(
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

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event.fromMap(data, doc.id);
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