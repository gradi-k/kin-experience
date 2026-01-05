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
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    // Couleur primaire (rouge) adoucie pour la cohérence avec le design minimaliste
    primaryColor: Constants.airbnbRed,
    colorScheme: const ColorScheme.light().copyWith(
      primary: Constants.airbnbRed,
      secondary: Constants.primaryBlue,
      tertiary: Constants.kinshasaGold,
      background: Color(0xFFF5F5F5),
      surface: Colors.white,
    ),
    // Polices système par défaut
    textTheme: ThemeData.light().textTheme,
    // Cartes aux coins plus doux et élévation réduite pour un effet aérien
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      centerTitle: true,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Constants.airbnbRed,
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
    primaryColor: Constants.airbnbRed,
    colorScheme: const ColorScheme.dark().copyWith(
      primary: Constants.airbnbRed,
      secondary: Constants.primaryBlue,
      tertiary: Constants.kinshasaGold,
      background: Color(0xFF0D0D0D),
      surface: Color(0xFF1A1A1A),
    ),
    textTheme: ThemeData.dark().textTheme,
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: const Color(0xFF1A1A1A),
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF1A1A1A),
      selectedItemColor: Constants.airbnbRed,
      unselectedItemColor: Colors.grey,
      elevation: 5,
      type: BottomNavigationBarType.fixed,
    ),
  );
}