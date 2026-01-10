import 'package:flutter/material.dart';

/// Ce fichier regroupe toutes les constantes utilisées dans l’application.
/// Les couleurs principales s’inspirent de la charte graphique d’Airbnb et
/// d’une interprétation dorée rappelant la ville de Kinshasa.  La section
/// citations mentionne la source des valeurs de couleur pour Airbnb【951395487120833†L12-L23】【524832607167485†L44-L49】.
class Constants {
  Constants._();

  /// Palette de couleurs principale de Kin‑Experience.
  /// Les trois couleurs définissent clairement l’identité visuelle :
  /// [primaryColor] pour le bleu profond (#1F2988), [secondaryColor]
  /// pour le jaune doré (#E9AE27) et [accentColor] pour le vert
  /// profond (#05814C).  Ces couleurs sont appliquées à
  /// l’ensemble de l’application et remplacent l’ancienne palette.
  static const Color primaryColor = Color(0xFF1F2988);
  static const Color secondaryColor = Color(0xFFE9AE27);
  static const Color accentColor = Color(0xFF05814C);

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