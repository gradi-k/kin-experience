import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle représentant un restaurant.  Similaire à [Site] mais
/// séparé afin de permettre des évolutions spécifiques à cette
/// catégorie (ex. menus, horaires).  Les méthodes de conversion
/// facilitent l’intégration avec Firestore.
class Resto {
  final String id;
  final String nom;
  final String description;
  final double rating;
  final double latitude;
  final double longitude;
  final List<String> photos;
  final String prixRange;
  final bool isFeatured;

  Resto({
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

  factory Resto.fromMap(Map<String, dynamic> data, String documentId) {
    return Resto(
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

  factory Resto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Resto.fromMap(data, doc.id);
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