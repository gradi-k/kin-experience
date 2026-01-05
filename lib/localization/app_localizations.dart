import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Gestionnaire de localisation personnalisé pour le projet.
/// Cette classe contient un tableau de traductions en français et en anglais
/// et fournit un accès pratique via la méthode [translate].  Elle est
/// inspirée de l’exemple « DemoLocalizations » présenté dans la
/// documentation Flutter【589070613539431†L1859-L1868】.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  // Liste des locales supportées
  static const supportedLocales = [
    Locale('fr'),
    Locale('en'),
  ];

  // Délégué pour Flutter
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Map des traductions.  La clé de premier niveau est la langue
  /// (fr/en) et la clé de second niveau est l’identifiant de la
  /// chaîne.  Certaines chaînes contiennent des caractères spéciaux
  /// (apostrophes typographiques) qui sont correctement échappés.
  static final Map<String, Map<String, String>> _localizedStrings = {
    'fr': {
      'search_hint': 'Où allez‑vous ?',
      'featured_title': 'Incontournables à Kinshasa',
      'all_sites': 'Tous les Sites',
      'all_restos': 'Tous les Restaurants',
      'all_hotels': 'Tous les Hôtels',
      'all_events': 'Tous les Évènements',
      'all_entreprises': 'Toutes les Entreprises',
      'no_results': 'Aucun résultat',
      'error_occurred': 'Une erreur est survenue\nVeuillez réessayer',
      'retry': 'Réessayer',
      'login': 'Connexion',
      'signup': 'Inscription',
      'email': 'Email',
      'password': 'Mot de passe',
      'sign_in': 'Se connecter',
      'sign_up': 'S\'inscrire',
      'switch_to_signup': 'Pas encore de compte ? Inscrivez‑vous',
      'switch_to_login': 'Déjà un compte ? Connectez‑vous',
      'admin_title': 'Panneau d’administration',
      'categories': 'Catégories',
      'add': 'Ajouter',
      'edit': 'Modifier',
      'delete': 'Supprimer',
      'name': 'Nom',
      'description': 'Description',
      'rating': 'Note',
      'latitude': 'Latitude',
      'longitude': 'Longitude',
      'price_range': 'Fourchette de prix',
      'photo_url': 'URL de la photo',
      'is_featured': 'Mis en avant',
      'save': 'Enregistrer',
      'cancel': 'Annuler',
      // étiquettes de la barre de navigation inférieure
      'nav_explore': 'Explorer',
      'nav_favorites': 'Favoris',
      'nav_profile': 'Profil',
      'nav_settings': 'Paramètres',
      'nav_admin': 'Admin',
      'logout': 'Déconnexion',
      'admin_panel': 'Panneau d’administration',
    // Paramètres
    'dark_mode': 'Mode sombre',
    'light_mode': 'Mode clair',
    'language': 'Langue',
    'about': 'À propos',
    'notifications': 'Notifications',
    'version': 'Version',
      // noms des catégories (pour le menu)
      'sites_label': 'Sites',
      'restos_label': 'Restaurants',
      'hotels_label': 'Hôtels',
      'events_label': 'Évènements',
      'entreprises_label': 'Entreprises',
      // Titres pour les écrans de connexion et d’inscription
      'login_title': 'Connexion à votre compte',
      'signup_title': 'Créer votre compte',
      // Champ de confirmation de mot de passe
      'confirm_password': 'Confirmer le mot de passe',
      // Texte des réseaux sociaux
      'or_sign_in_with': 'Ou se connecter avec',
      'or_sign_up_with': 'Ou s\'inscrire avec',
      'dont_have_account': 'Pas encore de compte ? Inscrivez‑vous',
      'already_have_account': 'Déjà inscrit ? Connectez‑vous',
    },
    'en': {
      'search_hint': 'Where are you going?',
      'featured_title': 'Must‑see in Kinshasa',
      'all_sites': 'All Sites',
      'all_restos': 'All Restaurants',
      'all_hotels': 'All Hotels',
      'all_events': 'All Events',
      'all_entreprises': 'All Businesses',
      'no_results': 'No results',
      'error_occurred': 'An error occurred\nPlease try again',
      'retry': 'Retry',
      'login': 'Login',
      'signup': 'Sign up',
      'email': 'Email',
      'password': 'Password',
      'sign_in': 'Sign in',
      'sign_up': 'Sign up',
      'switch_to_signup': 'Don\'t have an account? Sign up',
      'switch_to_login': 'Already have an account? Log in',
      'admin_title': 'Admin Panel',
      'categories': 'Categories',
      'add': 'Add',
      'edit': 'Edit',
      'delete': 'Delete',
      'name': 'Name',
      'description': 'Description',
      'rating': 'Rating',
      'latitude': 'Latitude',
      'longitude': 'Longitude',
      'price_range': 'Price range',
      'photo_url': 'Photo URL',
      'is_featured': 'Featured',
      'save': 'Save',
      'cancel': 'Cancel',
      // navigation bar labels
      'nav_explore': 'Explore',
      'nav_favorites': 'Favorites',
      'nav_profile': 'Profile',
      'nav_settings': 'Settings',
      'nav_admin': 'Admin',
      'logout': 'Log out',
      'admin_panel': 'Admin Panel',
    // Settings
    'dark_mode': 'Dark mode',
    'light_mode': 'Light mode',
    'language': 'Language',
    'about': 'About',
    'notifications': 'Notifications',
    'version': 'Version',
      // category names
      'sites_label': 'Sites',
      'restos_label': 'Restaurants',
      'hotels_label': 'Hotels',
      'events_label': 'Events',
      'entreprises_label': 'Businesses',
      // Titles for login and signup screens
      'login_title': 'Login to your Account',
      'signup_title': 'Create your Account',
      // Confirm password field
      'confirm_password': 'Confirm Password',
      // Social login text
      'or_sign_in_with': 'Or sign in with',
      'or_sign_up_with': 'Or sign up with',
      'dont_have_account': 'Don\'t have an account? Sign up',
      'already_have_account': 'Already have an account? Sign in',
    },
  };

  /// Récupère une chaîne traduite.  Si la clé n’existe pas pour la
  /// langue actuelle, on retourne la version anglaise par défaut.
  String translate(String key) {
    return _localizedStrings[locale.languageCode]?[key] ??
        _localizedStrings['en']![key] ?? key;
  }

  /// Méthode de commodité pour récupérer rapidement l’instance
  /// localisée dans un [BuildContext].
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }
}

/// Délégué chargé de charger les localisations.  Le chargement se fait
/// de manière synchrone puisqu’aucun fichier externe n’est nécessaire.
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .any((supported) => supported.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    // Utilisation de SynchronousFuture car le chargement est immédiat【589070613539431†L1879-L1895】.
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}