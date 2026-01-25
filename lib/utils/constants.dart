import 'package:flutter/material.dart';

/// Ce fichier regroupe toutes les constantes utilisées dans l'application.
/// Couleur primaire : VERT #05814C (Kinshasa green)
class Constants {
  Constants._();

  /// ✅ COULEUR PRIMAIRE : VERT (Kinshasa green)
  /// Cette couleur est utilisée dans toute l'application pour :
  /// - Le header de la home screen
  /// - Les boutons principaux
  /// - Les icônes actives
  /// - Le splash screen
  static const Color primaryColor = Color(0xFF05814C);  // VERT

  /// Couleur secondaire : Jaune doré
  static const Color secondaryColor = Color(0xFFE9AE27);  // JAUNE

  /// Couleur accent : Bleu
  static const Color accentColor = Color(0xFF1F2988);  // BLEU

  /// Couleur orange
  static const Color myOrange = Color(0xFFF18912);  // ORANGE

  // ✅ Aliases pour compatibilité avec l'ancien code
  static const Color kinBlue = accentColor;    // Bleu
  static const Color kinGold = secondaryColor;  // Jaune
  static const Color kinGreen = primaryColor;   // Vert (PRIMARY)

  /// Couleur de fond sombre pour le mode dark
  static const Color darkBackground = Color(0xFF121212);

  /// Rayon des cartes et des boutons
  static const double cardRadius = 24.0;

  /// Liste des catégories de lieux
  static const List<String> categories = [
    'sites',
    'restaurants',  // ✅ Nom de collection Firebase
    'hotels',
    'events',
    'entreprises',
    'shopping',  // ✅ Nom de collection Firebase
  ];
}