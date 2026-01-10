import 'package:flutter/material.dart';
// La dépendance google_fonts a été retirée ; nous utilisons désormais les polices par défaut du système.
import '../utils/constants.dart';

/// Définit les thèmes clair et sombre de l’application.  Chaque thème
/// reprend l’ADN visuel d’Airbnb (couleurs, typographie arrondie) tout en
/// ajoutant une touche locale via la couleur dorée.  La typographie Poppins
/// apporte modernité et lisibilité.
class AppTheme {
  AppTheme._();

  /// Thème clair pour la journée.
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    // Couleur de fond douce et claire pour un design moderne et épuré
    scaffoldBackgroundColor: Colors.white,
    // Couleur primaire bleue pour l’identité Kin‑Experience
    primaryColor: Constants.primaryColor,
    colorScheme: const ColorScheme.light().copyWith(
      primary: Constants.primaryColor,        // bleu profond
      secondary: Constants.secondaryColor,     // jaune doré
      tertiary: Constants.accentColor,     // vert accent
      background: Colors.white,
      surface: Colors.white,
    ),
    // Polices système par défaut
    textTheme: ThemeData.light().textTheme,
    // Cartes avec arrondi prononcé et ombre légère pour la profondeur
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      color: Colors.white,
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shadowColor: Colors.black.withOpacity(0.05),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      centerTitle: true,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Constants.primaryColor,
      unselectedItemColor: Colors.grey,
      elevation: 5,
      type: BottomNavigationBarType.fixed,
    ),
  );

  /// Thème sombre pour la nuit.  Le fond est un noir profond et les
  /// composants sont légèrement translucides afin de créer un effet
  /// glassmorphism subtil sur la barre de navigation inférieure.
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0D0D0D),
    primaryColor: Constants.primaryColor,
    colorScheme: const ColorScheme.dark().copyWith(
      primary: Constants.primaryColor,
      secondary: Constants.secondaryColor,
      tertiary: Constants.accentColor,
      background: Color(0xFF0D0D0D),
      surface: Color(0xFF1A1A1A),
    ),
    textTheme: ThemeData.dark().textTheme,
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      color: const Color(0xFF1A1A1A),
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shadowColor: Colors.black.withOpacity(0.1),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF1A1A1A),
      selectedItemColor: Constants.primaryColor,
      unselectedItemColor: Colors.grey,
      elevation: 5,
      type: BottomNavigationBarType.fixed,
    ),
  );
}