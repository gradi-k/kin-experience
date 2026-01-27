import 'package:flutter/material.dart';

const Map<String, IconData> amenitiesCatalog = {
  // Connexion & numérique
  'Wi-Fi': Icons.wifi,
  'Prises électriques': Icons.power,
  'Espace coworking': Icons.work_outline,
  'Salle de réunion': Icons.meeting_room_outlined,
  'Écran / Projecteur': Icons.tv_outlined,

  // Accès & stationnement
  'Parking': Icons.local_parking,
  'Parking sécurisé': Icons.local_parking_outlined,
  'Accès PMR': Icons.accessible_outlined,
  'Ascenseur': Icons.elevator_outlined,

  // Restauration
  'Petit-déjeuner': Icons.free_breakfast_outlined,
  'Restaurant': Icons.restaurant_outlined,
  'Bar / Lounge': Icons.local_bar_outlined,
  'Room service': Icons.room_service_outlined,
  'Terrasse': Icons.deck_outlined,

  // Bien-être & loisirs
  'Spa': Icons.spa_outlined,
  'Massage': Icons.spa,
  'Sauna': Icons.hot_tub_outlined,
  'Hammam': Icons.hot_tub,
  'Piscine': Icons.pool_outlined,
  'Salle de sport': Icons.fitness_center_outlined,
  'Jacuzzi': Icons.bathtub_outlined,

  // Confort & sécurité
  'Climatisation': Icons.ac_unit_outlined,
  'Générateur': Icons.electrical_services_outlined,
  'Sécurité 24h/24': Icons.security_outlined,
  'Caméras': Icons.videocam_outlined,

  // Famille
  'Espace enfants': Icons.child_friendly_outlined,
  'Aire de jeux': Icons.sports_esports_outlined,

  // Paiement
  'Paiement carte': Icons.credit_card_outlined,
  'Mobile Money': Icons.payments_outlined,

  // Animaux
  'Animaux acceptés': Icons.pets_outlined,
};

IconData amenityIcon(String name) {
  return amenitiesCatalog[name] ?? Icons.check_circle_outline;
}