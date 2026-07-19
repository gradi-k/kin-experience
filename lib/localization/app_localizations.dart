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
      // Bouton « Voir plus » pour afficher d’autres éléments
      'see_more': 'Voir plus',
      // Ouvre la grille des catégories non dépliées sur l’accueil
      'see_all_categories': 'Toutes les catégories',
      // Feuille « connexion requise » (voir views/auth/auth_guard.dart)
      'auth_required_title': 'Connexion requise',
      'auth_required_message':
          'Connectez-vous pour utiliser cette fonctionnalité.',
      'auth_required_favorites':
          'Connectez-vous pour enregistrer vos favoris et les retrouver sur tous vos appareils.',
      'auth_required_review': 'Connectez-vous pour laisser un avis.',
      'auth_required_like': 'Connectez-vous pour aimer ce contenu.',
      'auth_required_comment': 'Connectez-vous pour commenter.',
      'auth_required_profile': 'Connectez-vous pour accéder à votre profil.',
      'continue_as_guest': 'Continuer sans compte',
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
      'sites_label': 'Vos meilleurs endroits',
      'restos_label': 'Restaurants Tendances',
      'hotels_label': 'Hôtels',
      'events_label': 'Évènements',
      // 'Entreprises' devient 'Immo' pour représenter l’immobilier
      'entreprises_label': 'Business',
      'Shop_label':'Market',
      // Titres pour les écrans de connexion et d’inscription
      'login_title': 'Bienvenue Connectez-vous pour découvrir Kinshasa',
      'signup_title': 'Créer votre compte',
      // Champ de confirmation de mot de passe
      'confirm_password': 'Confirmer le mot de passe',
      // Texte des réseaux sociaux
      'or_sign_in_with': 'Ou se connecter avec',
      'or_sign_up_with': 'Ou s\'inscrire avec',
      'dont_have_account': 'Pas encore de compte ? Inscrivez‑vous',
      'already_have_account': 'Déjà inscrit ? Connectez‑vous',
      // Recherche
      'search': 'Rechercher',
      'all': 'Tous',
      'all_cities': 'Toutes les villes',
      'no_results_found': 'Aucun résultat trouvé',
      'start_searching': 'Commencez à rechercher',
      'try_other_keywords': 'Essayez avec d\'autres mots-clés ou filtres.',
      'discover_kinshasa': 'Découvrez les meilleurs lieux de Kinshasa.',
      // Détail
      'tab_info': 'Informations',
      'tab_reviews': 'Avis',
      'tab_community': 'Communauté',
      'about_section': 'À propos',
      'amenities': 'Équipements',
      'schedule': 'Horaires',
      'location_section': 'Localisation',
      'social_networks': 'Réseaux sociaux',
      'you_may_also_like': 'Vous pourriez aussi aimer',
      'open': 'Ouvert',
      'closed': 'Fermé',
      'see_all_photos': 'Voir toutes les photos',
      'directions': 'Itinéraire',
      // Carte
      'around_me': 'Autour de moi',
      'see_on_map': 'Voir sur la carte',
      'see_details': 'Voir les détails',
      'my_location': 'Ma position',
      // Divers
      'offline_banner': 'Mode hors-ligne — données en cache',
      'loading_error': 'Erreur de chargement du contenu.',
      'favorites_error': 'Impossible de charger vos favoris.',
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
      // Bouton « Voir plus » pour afficher d’autres éléments
      'see_more': 'See more',
      // Ouvre la grille des catégories non dépliées sur l’accueil
      'see_all_categories': 'All categories',
      // Feuille « connexion requise » (voir views/auth/auth_guard.dart)
      'auth_required_title': 'Sign in required',
      'auth_required_message': 'Sign in to use this feature.',
      'auth_required_favorites':
          'Sign in to save your favourites and find them on all your devices.',
      'auth_required_review': 'Sign in to leave a review.',
      'auth_required_like': 'Sign in to like this content.',
      'auth_required_comment': 'Sign in to comment.',
      'auth_required_profile': 'Sign in to access your profile.',
      'continue_as_guest': 'Continue without an account',
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
      // 'Businesses' devient 'Real Estate' pour représenter l’immobilier
      'entreprises_label': 'Real Estate',
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
      // Search
      'search': 'Search',
      'all': 'All',
      'all_cities': 'All cities',
      'no_results_found': 'No results found',
      'start_searching': 'Start searching',
      'try_other_keywords': 'Try other keywords or filters.',
      'discover_kinshasa': 'Discover the best places in Kinshasa.',
      // Detail
      'tab_info': 'Information',
      'tab_reviews': 'Reviews',
      'tab_community': 'Community',
      'about_section': 'About',
      'amenities': 'Amenities',
      'schedule': 'Opening hours',
      'location_section': 'Location',
      'social_networks': 'Social networks',
      'you_may_also_like': 'You may also like',
      'open': 'Open',
      'closed': 'Closed',
      'see_all_photos': 'See all photos',
      'directions': 'Directions',
      // Map
      'around_me': 'Around me',
      'see_on_map': 'See on the map',
      'see_details': 'See details',
      'my_location': 'My location',
      // Misc
      'offline_banner': 'Offline mode — cached data',
      'loading_error': 'Failed to load content.',
      'favorites_error': 'Unable to load your favorites.',
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