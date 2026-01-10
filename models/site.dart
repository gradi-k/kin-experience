import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle représentant un site touristique.  Chaque instance est
/// capable de se convertir vers/depuis Firestore.  La structure
/// reflète le schéma défini dans les instructions utilisateur.
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

  Site({
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

  /// Crée un objet [Site] à partir d'une carte de données Firestore.
  factory Site.fromMap(Map<String, dynamic> data, String documentId) {
    return Site(
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

  /// Crée un objet [Site] à partir d'un document Firestore.
  factory Site.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Site.fromMap(data, doc.id);
  }

  /// Convertit ce [Site] en une carte pour Firestore.
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