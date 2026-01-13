import 'contact_info.dart';
import 'social_links.dart';
import 'review.dart';
import 'community_post.dart';

abstract class PlaceBase {
  String get id;
  String get nom;
  String get description;
  double get rating;
  double get latitude;
  double get longitude;
  List<dynamic> get photos;
  String get prixRange;
  bool get isFeatured;

  // ✅ Nouveaux champs communs
  ContactInfo get contact;
  SocialLinks get socials;

  List<String> get amenities; // équipements
  String? get schedule; // horaires

  int get reviewCount; // nb avis
  double get distanceKm; // distance

  // ✅ (optionnel) si tu veux charger depuis Firestore
  List<Review> get avis;
  List<CommunityPost> get communautes;

  // ✅ informations (groupe)
  Map<String, dynamic> get informations;

  Map<String, dynamic> toMap();
}
