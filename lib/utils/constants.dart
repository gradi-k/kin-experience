import 'package:flutter/material.dart';

/// Ce fichier regroupe toutes les constantes utilisées dans l’application.
/// Les couleurs principales s’inspirent de la charte graphique d’Airbnb et
/// d’une interprétation dorée rappelant la ville de Kinshasa.  La section
/// citations mentionne la source des valeurs de couleur pour Airbnb【951395487120833†L12-L23】【524832607167485†L44-L49】.
class Constants {
  Constants._();

  /// Rouge principal (Rausch) utilisé par Airbnb.
  /// Source : Pick Color Online【951395487120833†L12-L23】.
  static const Color airbnbRed = Color(0xFFFF5A5F);

  /// Bleu secondaire inspiré des couleurs d’Airbnb.
  /// Source : Pick Color Online【951395487120833†L12-L23】.
  static const Color primaryBlue = Color(0xFF00A699);

  /// Couleur dorée représentant la richesse culturelle de Kinshasa.
  static const Color kinshasaGold = Color(0xFFB49A5D);

  /// Couleur de fond sombre pour le mode dark.
  static const Color darkBackground = Color(0xFF121212);

  /// Rayon des cartes et des boutons.
  static const double cardRadius = 24.0;

  /// Liste des catégories de lieux.
  static const List<String> categories = [
    'sites',
    'restos',
    'hotels',
    'events',
    'entreprises',
  ];
}