# 🌍 Kin Experience — City Guide de Kinshasa

> Application mobile Flutter de type **city guide** dédiée à la ville de **Kinshasa (RDC)**.
> Elle permet aux utilisateurs de découvrir des lieux (restaurants, hôtels, sites touristiques, événements, commerces, entreprises), de visionner des Reels vidéo, de gérer leurs favoris et de recevoir des notifications en temps réel.

---

## 📋 Table des matières

1. [Aperçu du projet](#-aperçu-du-projet)
2. [Stack technique](#-stack-technique)
3. [Architecture du projet](#-architecture-du-projet)
4. [Structure des dossiers](#-structure-des-dossiers)
5. [Modèles de données](#-modèles-de-données)
6. [Services](#-services)
7. [Contrôleurs (State Management)](#-contrôleurs-state-management)
8. [Écrans principaux](#-écrans-principaux)
9. [Widgets réutilisables](#-widgets-réutilisables)
10. [Fonctionnalités](#-fonctionnalités)
11. [Backend Firebase](#-backend-firebase)
12. [Localisation (i18n)](#-localisation-i18n)
13. [Thèmes](#-thèmes)
14. [Prérequis et installation](#-prérequis-et-installation)
15. [Configuration Firebase](#-configuration-firebase)
16. [Collections Firestore](#-collections-firestore)
17. [Variables d'environnement](#-variables-denvironnement)
18. [Lancer le projet](#-lancer-le-projet)
19. [Données de test](#-données-de-test)

---

## 🔭 Aperçu du projet

**Kin Experience** (package : `kin_experience`) est une application mobile de découverte urbaine destinée aux habitants et visiteurs de Kinshasa. Elle offre :

- Un **catalogue de lieux** répartis en 6 catégories (Restaurants, Hôtels, Sites touristiques, Événements, Entreprises, Shopping/Marchés)
- Un flux de **Reels vidéo** (type TikTok/Instagram) associés aux lieux
- Un **système de favoris** persisté dans Firestore
- Une **boutique intégrée** (e-commerce basique avec produits)
- Un **panneau d'administration** complet pour gérer les contenus, publicités et Reels
- Un système d'**authentification dual** (email + téléphone) avec vérification OTP
- Des **notifications push** via Firebase Cloud Messaging
- La **géolocalisation** de l'utilisateur avec calcul de distances
- Un mode **sombre/clair** et une localisation **français/anglais**

---

## 🛠 Stack technique

| Composant | Technologie |
|---|---|
| **Framework** | Flutter (Dart) |
| **State management** | Riverpod (flutter_riverpod) |
| **Backend** | Firebase (Firestore, Auth, Storage, Messaging, App Check) |
| **Authentification** | Firebase Auth (Email/Password + Phone OTP) |
| **Base de données** | Cloud Firestore (temps réel) |
| **Stockage fichiers** | Firebase Storage (images, vidéos compressées en WebP) |
| **Notifications** | Firebase Cloud Messaging + flutter_local_notifications |
| **Géolocalisation** | Geolocator + Geocoding + API Nominatim (OpenStreetMap) |
| **Images** | cached_network_image, flutter_image_compress |
| **Persistance locale** | SharedPreferences (onboarding, thème) |
| **HTTP** | package http (pour le géocodage Nominatim) |

---

## 🏗 Architecture du projet

L'application suit une architecture en **couches** inspirée du pattern **MVC + Repository** :

```
┌─────────────────────────────────────────┐
│               VIEWS (UI)                │  Écrans, Widgets
├─────────────────────────────────────────┤
│           CONTROLLERS                   │  Riverpod Providers & StateNotifiers
├─────────────────────────────────────────┤
│        SERVICES / REPOSITORIES          │  Logique métier, accès Firestore
├─────────────────────────────────────────┤
│              MODELS                     │  Classes de données (Dart)
├─────────────────────────────────────────┤
│         FIREBASE (Backend)              │  Firestore, Auth, Storage, FCM
└─────────────────────────────────────────┘
```

**Flux de données** : Les Views observent des `StreamProvider` / `FutureProvider` Riverpod qui eux-mêmes écoutent les Repositories/Services connectés à Firestore en temps réel.

---

## 📁 Structure des dossiers

```
lib/
├── main.dart                      # Point d'entrée, init Firebase, routage auth
├── firebase_options.dart          # Config Firebase par plateforme
│
├── models/                        # Modèles de données
│   ├── place_base.dart            # Classe abstraite commune à tous les lieux
│   ├── place_enums.dart           # Enum PlaceCategory + extensions
│   ├── place_category_ext.dart    # Extensions de catégorie
│   ├── model_helpers.dart         # Parseurs robustes (double, bool, List, photos)
│   ├── hotel.dart                 # Modèle Hôtel
│   ├── resto.dart                 # Modèle Restaurant
│   ├── site.dart                  # Modèle Site touristique
│   ├── event.dart                 # Modèle Événement
│   ├── entreprise.dart            # Modèle Entreprise / Business
│   ├── shopping.dart              # Modèle Shopping / Marché
│   ├── product.dart               # Modèle Produit (boutique)
│   ├── ad_model.dart              # Modèle Publicité
│   ├── reel.dart                  # Modèle Reel vidéo + ReelComment
│   ├── review.dart                # Modèle Avis
│   ├── community_post.dart        # Modèle Post communautaire
│   ├── contact_info.dart          # Modèle Informations de contact
│   ├── social_links.dart          # Modèle Liens réseaux sociaux
│   └── app_notification.dart      # Modèle Notification in-app
│
├── controllers/                   # State management (Riverpod)
│   ├── auth_controller.dart       # Auth state, providers, AuthWrapper, AuthGuard
│   ├── dual_auth_controller.dart  # Auth dual (email + phone), AuthService
│   ├── two_factor_controller.dart # Contrôleur 2FA (vide/placeholder)
│   ├── places_controller.dart     # Providers pour tous les lieux, recherche, sections Home
│   ├── favorites_controller.dart  # Gestion des favoris (Firestore user sub-collection)
│   ├── location_controller.dart   # Géolocalisation, ville/commune de l'utilisateur
│   ├── theme_controller.dart      # Mode sombre/clair (SharedPreferences)
│   └── notification_controller.dart # Provider compteur notifications non-lues
│
├── services/                      # Couche service / accès données
│   ├── places_service.dart        # Service CRUD Firestore (watch + fetch par catégorie)
│   ├── places_repository.dart     # Repository principal (utilisé par les controllers)
│   ├── location_service.dart      # GPS : getCurrentPosition, calcul distance
│   ├── geocoding_service.dart     # Géocodage Nominatim (adresse ↔ coordonnées)
│   ├── notification_service.dart  # FCM + notifications locales
│   ├── new_place_watcher_service.dart # Surveillance ajouts Firestore → notifs
│   ├── ad_service.dart            # CRUD publicités (Firebase Storage + Firestore)
│   ├── content_service.dart       # CRUD contenus + brouillons (admin)
│   └── image_service.dart         # Compression/upload d'images
│
├── repositories/                  # Repository pattern (CRUD avancé)
│   └── places_repository.dart     # PlaceItem model + CRUD + upload images + brouillons
│
├── views/                         # Écrans de l'application
│   ├── home_screen.dart           # Écran principal (Explorer) avec sections dynamiques
│   ├── auth_screen.dart           # Connexion/Inscription (email + phone)
│   ├── auth_wrapper.dart          # Wrapper de redirection selon auth state
│   ├── dual_auth_screen.dart      # Écran d'auth dual (email + phone)
│   ├── otp_verification_screen.dart # Vérification OTP (email ou SMS)
│   ├── onboarding_screen.dart     # Écrans d'onboarding (1ère utilisation)
│   ├── detail_screen.dart         # Détail d'un lieu (2150 lignes — très complet)
│   ├── category_list_screen.dart  # Liste par catégorie
│   ├── global_search_screen.dart  # Recherche globale multi-catégories
│   ├── favorites_screen.dart      # Écran des favoris de l'utilisateur
│   ├── reels_screen.dart          # Lecteur de Reels vidéo (type TikTok)
│   ├── shop_screen.dart           # Boutique intégrée
│   ├── shop_products_screen.dart  # Liste des produits de la boutique
│   ├── product_detail_screen.dart # Détail d'un produit
│   ├── profile_screen.dart        # Profil utilisateur
│   ├── edit_profile_screen.dart   # Édition du profil
│   ├── settings_screen.dart       # Paramètres (thème, langue, etc.)
│   ├── notifications_screen.dart  # Liste des notifications
│   ├── account_security_screen.dart # Sécurité du compte
│   ├── admin_screen.dart          # Panneau d'administration
│   │
│   ├── admin/                     # Sous-écrans d'administration
│   │   ├── ads/                   # Gestion des publicités
│   │   │   ├── ads_list_screen.dart
│   │   │   ├── add_ad_form.dart
│   │   │   └── edit_ad_form.dart
│   │   ├── contents/              # Gestion des contenus (lieux)
│   │   │   ├── content_list_screen.dart
│   │   │   ├── add_content_form.dart
│   │   │   ├── edit_content_form.dart
│   │   │   ├── drafts_screen.dart
│   │   │   └── edit_draft_form.dart
│   │   └── reels/                 # Gestion des Reels
│   │       ├── reels_list_screen.dart
│   │       └── add_reel_form.dart
│   │
│   └── widgets/                   # Widgets réutilisables
│       ├── place_card.dart        # Carte lieu (image + nom + rating)
│       ├── featured_carousel.dart # Carrousel des lieux mis en avant
│       ├── ads_banner_carousel.dart # Carrousel de publicités
│       ├── bottom_nav_bar.dart    # Barre de navigation inférieure
│       ├── address_search_field.dart # Champ de recherche d'adresse (Nominatim)
│       ├── address_location_picker.dart # Sélecteur d'adresse + carte
│       ├── opening_hours_picker.dart # Sélecteur d'horaires d'ouverture
│       ├── schedule_picker_field.dart # Champ sélecteur de planning
│       └── menu_picker.dart       # Sélecteur de menu (admin)
│
├── themes/
│   └── app_theme.dart             # Définition des thèmes (light/dark)
│
├── localization/
│   └── app_localizations.dart     # Traductions FR/EN (hardcodées en Map)
│
├── utils/
│   ├── constants.dart             # Couleurs, rayons, catégories
│   └── amenities_icons.dart       # Mapping nom d'équipement → IconData
│
└── data/                          # Données fictives (développement)
    ├── fake_data.dart             # ~2000 lignes de données de test (lieux)
    ├── fake_shop_data.dart        # Données boutique fictives
    ├── fake_products.dart         # Produits fictifs
    ├── fake_reels.dart            # Reels fictifs
    └── fake_ads.dart              # Publicités fictives
```

**Statistiques** : 87 fichiers Dart, ~29 885 lignes de code.

---

## 📦 Modèles de données

### PlaceBase (classe abstraite)

Interface commune à tous les types de lieux, définissant les champs obligatoires : `id`, `nom`, `description`, `rating`, `latitude`, `longitude`, `photos`, `prixRange`, `isFeatured`, `contact`, `socials`, `amenities`, `schedule`, `reviewCount`, `distanceKm`, `avis`, `communautes`, `informations`.

### PlaceCategory (enum)

6 catégories avec extensions pour les labels, icônes et noms de collection Firestore :

| Enum | Label UI | Collection Firestore | Icône |
|---|---|---|---|
| `resto` | Restaurants | `restaurants` | 🍽 |
| `hotel` | Hôtels | `hotels` | 🏨 |
| `event` | Événements | `events` | 📅 |
| `site` | Sites | `sites` | 📍 |
| `entreprise` | Business | `business` | 🏢 |
| `shopping` | Market | `shopping` | 🛍 |

### Modèles concrets

Chaque modèle de lieu (`Hotel`, `Resto`, `Site`, `Event`, `Entreprise`, `Shopping`) partage les mêmes champs :
- Identité : `id`, `nom`, `description`
- Géo : `latitude`, `longitude`, `address`
- Média : `photos` (List<String>)
- Évaluation : `rating`, `reviewCount`, `prixRange`
- Contact : `phone`, `email`, `website`
- Réseaux sociaux : `facebookUrl`, `instagramUrl`, `tiktokUrl`
- Métadonnées : `amenities`, `schedule`, `isFeatured`, `distanceKm`

Chaque modèle a un `fromMap(Map, String id)` et un `toMap()` utilisant `ModelHelpers` pour un parsing robuste de Firestore.

### Autres modèles

- **`AdModel`** : Publicité avec `title`, `subtitle`, `image`, `ctaLabel`, `link`, `isActive`, timestamps
- **`Reel`** : Vidéo courte avec `videoUrl`, `authorName`, `caption`, `location`, liaison optionnelle à un lieu (`placeId`, `placeCategory`)
- **`ReelComment`** : Commentaire avec système de réponses hiérarchiques (`parentId`)
- **`Product`** : Produit e-commerce avec `price`, `brand`, `colors`, `category`, `isDeal`
- **`AppNotification`** : Notification in-app
- **`ContactInfo`**, **`SocialLinks`**, **`Review`**, **`CommunityPost`** : Sous-modèles réutilisables

---

## ⚙️ Services

| Service | Responsabilité |
|---|---|
| **`PlacesService`** | Streams et fetch one-shot Firestore pour les 6 catégories + featured |
| **`PlacesRepository`** (services/) | Repository principal : watch/fetch toutes catégories, `watchAllPlaces()`, `watchFeaturedPlaces()`, `watchByCategory()` |
| **`PlacesRepository`** (repositories/) | CRUD avancé : `PlaceItem` model, upload images, gestion brouillons, delete |
| **`LocationService`** | GPS via Geolocator, calcul de distance, formatage |
| **`GeocodingService`** | Géocodage/inverse via Nominatim (gratuit, sans clé API), autocomplétion d'adresses, filtré sur la RDC (`countrycodes: 'cd'`) |
| **`NotificationService`** | Singleton — init FCM, notifications locales, gestion tokens, stockage Firestore |
| **`NewPlaceWatcherService`** | Écoute en temps réel les ajouts dans les 6 collections → génère des notifications automatiques |
| **`AdsService`** | CRUD publicités : stream actives/toutes, upload image compressée en WebP |
| **`ContentService`** | Orchestration contenus + brouillons pour le panneau admin |
| **`ImageService`** | Compression et upload d'images vers Firebase Storage |

---

## 🎮 Contrôleurs (State Management)

Le projet utilise **Riverpod** avec les patterns suivants :

- **`StreamProvider`** pour les données temps réel Firestore (lieux, favoris, pubs)
- **`FutureProvider`** pour les données chargées une fois (position GPS, ville, statut admin)
- **`StateNotifierProvider`** pour les états mutables (recherche, favoris)
- **`Provider`** pour les singletons (services)

### Providers principaux

| Provider | Type | Description |
|---|---|---|
| `sitesProvider` / `restosProvider` / etc. | StreamProvider | Données temps réel par catégorie |
| `allPlacesProvider` | StreamProvider | Tous les lieux combinés |
| `featuredPlacesProvider` | StreamProvider | Lieux mis en avant |
| `homeSectionsProvider` | Provider | Sections structurées pour la Home |
| `searchProvider` | StateNotifierProvider | Recherche globale avec filtres |
| `favoritesControllerProvider` | StateNotifierProvider | Gestion favoris (CRUD Firestore) |
| `authStateProvider` | StreamProvider | État d'authentification Firebase |
| `isAdminProvider` | FutureProvider | Vérification rôle admin |
| `userPositionProvider` | FutureProvider | Position GPS |
| `userCityCommuneProvider` | FutureProvider | Ville + commune géocodée |
| `themeModeProvider` | StateNotifierProvider | Mode sombre/clair |
| `unreadNotificationsCountProvider` | StreamProvider | Badge notifications |

---

## 📱 Écrans principaux

### Flux d'entrée (main.dart)

```
App Launch → SplashScreen (3s)
  → 1ère fois ? → OnboardingScreen → AuthScreen
  → Déjà vu ?  → AuthGate
                    ├─ Non connecté → AuthScreen
                    ├─ Connecté + Non vérifié → OtpVerificationScreen
                    ├─ Connecté + Vérifié + Admin → AdminScreen
                    └─ Connecté + Vérifié + User  → HomeScreen
```

### HomeScreen

Écran principal avec 4 onglets via `BottomNavBar` : Explorer, Reels, Shop, Profil. L'onglet Explorer inclut :
- Header vert avec localisation et badge notifications
- Carrousel des lieux en vedette (`FeaturedCarousel`)
- Bannière publicitaire (`AdsBannerCarousel`)
- Sections par catégorie avec scroll horizontal de `PlaceCard`
- Accès rapide aux catégories (icônes avec contour blanc)

### DetailScreen (~2150 lignes)

Écran de détail très riche avec : carrousel photos, notation, description, amenities, horaires, carte intégrée, réseaux sociaux, avis, posts communautaires, bouton favori, partage.

### AdminScreen

Panneau d'admin avec gestion complète des contenus (CRUD par catégorie), publicités et Reels. Système de brouillons pour les contenus en cours de rédaction.

### ReelsScreen (~1465 lignes)

Lecteur de vidéos courtes style TikTok avec système de likes, commentaires et liaison aux lieux.

---

## 🧩 Widgets réutilisables

| Widget | Description |
|---|---|
| `PlaceCard` | Carte lieu avec image, nom, rating, animation de pression |
| `FeaturedCarousel` | Carrousel horizontal des lieux mis en avant |
| `AdsBannerCarousel` | Carrousel de publicités avec CTA |
| `BottomNavBar` | Barre de navigation inférieure personnalisée |
| `AddressSearchField` | Champ de recherche d'adresse avec autocomplétion Nominatim |
| `AddressLocationPicker` | Sélecteur d'adresse complet avec carte |
| `OpeningHoursPicker` | Sélecteur d'horaires d'ouverture (admin) |
| `SchedulePickerField` | Champ de planning (admin) |
| `MenuPicker` | Sélecteur de menu pour formulaires admin |

---

## ✨ Fonctionnalités

### Authentification
- Inscription/connexion par email + mot de passe
- Authentification par numéro de téléphone (OTP SMS)
- Liaison des deux méthodes (dual auth)
- Vérification OTP par email ou SMS après inscription
- Liste blanche d'administrateurs (emails hardcodés + champ Firestore)

### Gestion des lieux
- 6 catégories avec données temps réel Firestore
- Système de mise en avant (featured)
- Recherche globale multi-catégories
- Filtrage par catégorie
- Calcul de distance GPS
- Détail riche (photos, carte, contact, avis, etc.)

### Reels vidéo
- Flux vertical de vidéos courtes
- Likes et commentaires (avec réponses)
- Liaison à un lieu (navigation vers le détail)
- Gestion admin (ajout/suppression)

### Boutique (Shop)
- Catalogue de produits par catégorie
- Page détail produit
- Données actuellement statiques (fake data)

### Favoris
- Ajout/suppression en un tap
- Persistance dans une sous-collection Firestore `users/{uid}/favorites`
- Synchronisation temps réel

### Notifications
- Push via FCM
- Notifications locales
- Surveillance automatique des nouveaux lieux ajoutés
- Badge compteur de non-lus

### Administration
- CRUD complet pour les 6 catégories de lieux
- Système de brouillons
- Gestion des publicités (upload image, activation/désactivation)
- Gestion des Reels

---

## 🔥 Backend Firebase

### Collections Firestore

| Collection | Description | Modèle |
|---|---|---|
| `sites` | Sites touristiques | `Site` |
| `restaurants` | Restaurants | `Resto` |
| `hotels` | Hôtels | `Hotel` |
| `events` | Événements | `Event` |
| `business` | Entreprises | `Entreprise` |
| `shopping` | Commerces / Marchés | `Shopping` |
| `ads` | Publicités | `AdModel` |
| `reels` | Vidéos courtes | `Reel` |
| `drafts` | Brouillons (admin) | `PlaceItem` |
| `users` | Profils utilisateurs | Map |
| `users/{uid}/favorites` | Favoris par utilisateur | Copy du lieu |
| `users/{uid}/notifications` | Notifications | `AppNotification` |

### Firebase Storage

- `ads/<adId>/<filename>.webp` — Images des publicités (compressées en WebP)
- Images des lieux uploadées via admin

### Firebase App Check

Activé avec `PlayIntegrity` en production et mode `debug` en développement.

---

## 🌐 Localisation (i18n)

Système de localisation personnalisé (`AppLocalizations`) avec un dictionnaire statique `Map<String, Map<String, String>>` supportant :
- **Français** (locale par défaut : `fr_FR`)
- **Anglais** (`en_US`)

Les traductions couvrent les labels UI, messages d'erreur, noms de catégories, actions, etc.

---

## 🎨 Thèmes

Deux thèmes Material 3 sont définis dans `main.dart` :

| Propriété | Light | Dark |
|---|---|---|
| Primaire | `#05814C` (vert Kinshasa) | `#05814C` |
| Secondaire | `#E9AE27` (doré) | `#FFAB40` |
| Background | `grey.shade50` | `#121212` |
| AppBar | Blanc | Vert primaire |
| Cards | Blanches, ombre légère | `#1E1E1E` |

Le mode est persisté via `SharedPreferences` et géré par `themeModeProvider`.

---

## 📋 Prérequis et installation

### Prérequis

- Flutter SDK >= 3.x
- Dart SDK >= 3.x
- Compte Firebase avec projet configuré
- Android Studio / VS Code
- Un device Android ou iOS (ou émulateur)

### Dépendances principales (pubspec.yaml)

```yaml
dependencies:
  flutter_riverpod:          # State management
  firebase_core:             # Firebase
  firebase_auth:             # Authentification
  cloud_firestore:           # Base de données
  firebase_storage:          # Stockage fichiers
  firebase_messaging:        # Push notifications
  firebase_app_check:        # Sécurité
  flutter_local_notifications: # Notifications locales
  geolocator:                # GPS
  geocoding:                 # Géocodage inversé
  cached_network_image:      # Cache images réseau
  flutter_image_compress:    # Compression images
  shared_preferences:        # Stockage local
  http:                      # Requêtes HTTP (Nominatim)
```

---

## 🔧 Configuration Firebase

1. Créer un projet Firebase
2. Activer Authentication (Email/Password + Phone)
3. Créer la base Firestore
4. Activer Firebase Storage
5. Activer Cloud Messaging
6. Exécuter `flutterfire configure` pour générer `firebase_options.dart`
7. Remplacer les valeurs placeholder dans `firebase_options.dart`

---

## 🚀 Lancer le projet

```bash
# Cloner le repo
git clone <repo_url>
cd kin_experience

# Installer les dépendances
flutter pub get

# Configurer Firebase
flutterfire configure

# Lancer sur un device/émulateur
flutter run
```

---

## 🧪 Données de test

Le dossier `lib/data/` contient des fichiers de données fictives (~2 500 lignes) pour le développement sans connexion Firebase :
- `fake_data.dart` — Lieux de toutes catégories (~2 000 lignes)
- `fake_shop_data.dart` — Boutiques et produits
- `fake_products.dart` — Catalogue de produits
- `fake_reels.dart` — Reels vidéo
- `fake_ads.dart` — Publicités

---

## 👥 Rôles utilisateur

| Rôle | Accès | Détermination |
|---|---|---|
| **Utilisateur** | Exploration, favoris, reels, boutique, profil | Par défaut |
| **Admin** | Tout + panneau d'administration | Email dans whitelist OU champ Firestore `isAdmin: true` / `role: 'admin'` |

### Emails admin hardcodés

```dart
const Set<String> _adminEmails = {
  'admin@mail.com',
  'tys@mail.com',
  'user@mail.com',
};
```

---

## 📄 Licence

Propriétaire — Tous droits réservés.

---

# 🔧 PROPOSITIONS D'AMÉLIORATION

## 1. Architecture & Code Quality

### 1.1 🔴 Critique — Éliminer la duplication massive des modèles

**Problème** : Les modèles `Hotel`, `Resto`, `Site`, `Event`, `Entreprise`, `Shopping` sont quasi-identiques (mêmes champs, mêmes méthodes). Cela représente ~600 lignes de code dupliqué.

**Solution** : Faire implémenter `PlaceBase` à une classe concrète unique `Place` avec un champ `category`, ou a minima utiliser des mixins.

```dart
class Place implements PlaceBase {
  final PlaceCategory category;
  final String id, nom, description;
  // ... tous les champs communs

  factory Place.fromMap(Map<String, dynamic> map, String id, PlaceCategory category) { ... }
}
```

### 1.2 🔴 Critique — Supprimer le double repository

**Problème** : Il existe **deux fichiers** `places_repository.dart` — un dans `services/` et un dans `repositories/`. Le service `PlacesService` dans `services/places_service.dart` duplique également une grande partie de la logique. Cela crée confusion et incohérences (noms de collection différents : `entreprises` vs `business`).

**Solution** : Fusionner en un seul `PlacesRepository` dans `repositories/`, supprimer les doublons, et injecter via un `Provider` unique.

### 1.3 🔴 Critique — Providers dupliqués entre controllers

**Problème** : `auth_controller.dart` et `dual_auth_controller.dart` déclarent tous deux `authStateProvider`, `currentUserProvider`, `isAuthenticatedProvider`, `isAdminProvider` avec des noms identiques. Cela provoque des conflits d'import et des comportements imprévisibles.

**Solution** : Consolider en un seul fichier `auth_controller.dart` avec tous les providers d'authentification.

### 1.4 🟡 Important — Éliminer les `dynamic` dans les providers

**Problème** : `allPlacesProvider`, `featuredPlacesProvider`, `favoritesControllerProvider` retournent `List<dynamic>`. Cela supprime le type safety et nécessite des `is` checks partout.

**Solution** : Avec un modèle `Place` unifié, tous les providers retourneraient `List<Place>`.

### 1.5 🟡 Important — Extraire le thème de main.dart

**Problème** : `main.dart` contient ~300 lignes, incluant les définitions complètes des deux thèmes. Le fichier `themes/app_theme.dart` existe mais n'est pas utilisé.

**Solution** : Déplacer `_buildLightTheme()` et `_buildDarkTheme()` dans `app_theme.dart`.

### 1.6 🟡 Important — Découper le DetailScreen (2150 lignes)

**Problème** : `detail_screen.dart` est un fichier monolithique de 2150 lignes, difficile à maintenir.

**Solution** : Extraire en sous-widgets : `DetailPhotoCarousel`, `DetailContactSection`, `DetailReviewsSection`, `DetailMapSection`, etc.

---

## 2. Sécurité

### 2.1 🔴 Critique — Supprimer les emails admin hardcodés

**Problème** : Les emails admin sont en clair dans le code source (`admin@mail.com`, `tys@mail.com`, `user@mail.com`). N'importe qui lisant le code peut se créer un compte admin. De plus, `user@mail.com` est un nom suspect pour un admin.

**Solution** : Utiliser uniquement la vérification Firestore (`isAdmin` field) ou les Custom Claims Firebase Auth. Supprimer toute whitelist du code.

### 2.2 🔴 Critique — Nettoyage des `print()` et `debugPrint()`

**Problème** : Le code est parsemé de `print('❤️ toggleFavorite...')`, `print('✅ Admin by email...')`, etc. En production, cela expose des informations sensibles (emails admin, UIDs, statuts).

**Solution** : Remplacer par un logger conditionnel (`kDebugMode`) ou un package comme `logger`.

### 2.3 🟡 Important — Sécuriser les règles Firestore

**Problème** : Aucune indication des règles Firestore. Sans règles strictes, n'importe quel utilisateur authentifié pourrait modifier les collections admin.

**Solution** : Documenter et implémenter des règles Firestore restrictives, par exemple :
```
match /restaurants/{docId} {
  allow read: if request.auth != null;
  allow write: if request.auth.token.admin == true;
}
```

---

## 3. Performance

### 3.1 🔴 Critique — Optimiser le chargement de la Home

**Problème** : `homeSectionsProvider` ouvre **6 streams Firestore simultanés** (un par catégorie) au démarrage. `allPlacesProvider` en ouvre 6 de plus. Cela fait potentiellement **12 listeners Firestore** dès l'ouverture de l'app.

**Solution** :
- Utiliser une **pagination** (`.limit(10)` par catégorie sur la Home)
- Charger `allPlaces` uniquement quand l'écran de recherche est ouvert
- Implémenter un cache local (`Hive` ou `drift`) pour réduire les reads Firestore

### 3.2 🟡 Important — Ajouter de la pagination

**Problème** : Tous les streams Firestore chargent la totalité des documents sans limite. Avec une croissance de la base, cela deviendra très lent et coûteux.

**Solution** : Implémenter une pagination avec curseurs Firestore (`startAfterDocument`) et un mécanisme de "charger plus".

### 3.3 🟡 Important — Optimiser les images

**Problème** : Les images sont chargées en taille originale. Pas de thumbnails, pas de gestion du format responsive.

**Solution** : Utiliser Firebase Extensions (Resize Images) pour générer automatiquement des thumbnails. Charger les thumbnails dans les listes et l'image complète uniquement dans le détail.

---

## 4. Fonctionnalités manquantes

### 4.1 🟡 Ajouter des tests unitaires et widget tests

**Problème** : Aucun test n'est présent dans le projet. Avec ~30 000 lignes de code, c'est un risque majeur.

**Solution** : Commencer par tester les `ModelHelpers`, les Repositories (avec Firestore mocké), et les Providers.

### 4.2 🟡 Implémenter le routing déclaratif

**Problème** : La navigation utilise `Navigator.push` / `pushAndRemoveUntil` de manière impérative. Cela rend le deep linking impossible et complique le maintien.

**Solution** : Migrer vers `go_router` pour un routing déclaratif avec support du deep linking.

### 4.3 🟢 Améliorer la boutique

**Problème** : La boutique utilise uniquement des données statiques (`fake_products.dart`). Il n'y a ni panier, ni paiement, ni gestion de commandes.

**Solution** : Soit supprimer la fonctionnalité si ce n'est pas une priorité, soit implémenter un vrai backend e-commerce avec panier Firestore et intégration de paiement mobile (M-Pesa, Airtel Money, etc. — pertinent pour la RDC).

### 4.4 🟢 Ajouter un système de reviews complet

**Problème** : Le modèle `Review` existe mais il n'y a aucune UI ni logique pour que les utilisateurs laissent des avis.

**Solution** : Ajouter un formulaire d'avis avec notation par étoiles, texte, et modération admin.

### 4.5 🟢 Support hors ligne (offline-first)

**Problème** : L'app ne fonctionne pas du tout sans connexion Internet.

**Solution** : Activer la persistance Firestore offline (`FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true)`) et gérer les états "pas de réseau" dans l'UI.

---

## 5. UX / UI

### 5.1 🟡 Responsive design inachevé

**Problème** : La classe `ResponsiveSize` dans `home_screen.dart` est un bon début mais n'est pas extraite ni réutilisée dans les autres écrans.

**Solution** : Extraire `ResponsiveSize` dans un fichier utilitaire et l'utiliser systématiquement.

### 5.2 🟡 Gestion d'erreurs côté UI

**Problème** : Beaucoup de `try/catch` absorbent les erreurs silencieusement (`catch (_) { return ''; }`). L'utilisateur n'est pas informé des problèmes.

**Solution** : Implémenter un système de Snackbar ou Toast pour les erreurs non-bloquantes, et des écrans d'erreur dédiés pour les erreurs critiques.

### 5.3 🟢 Animations et transitions

**Problème** : Pas d'animations de transition entre les écrans. L'expérience est un peu abrupte.

**Solution** : Ajouter des `Hero` animations sur les images des PlaceCard vers le DetailScreen, et des transitions de page personnalisées.

---

## 6. DevOps & Outillage

### 6.1 🟡 Ajouter l'analyse statique

**Solution** : Configurer `analysis_options.yaml` avec des règles strictes (`flutter_lints` + custom rules) et activer `very_good_analysis` pour un lint exhaustif.

### 6.2 🟡 CI/CD

**Solution** : Mettre en place GitHub Actions ou Codemagic pour : lint, tests, build APK/IPA, déploiement automatique sur Firebase App Distribution.

### 6.3 🟢 Configuration par environnement

**Problème** : Les URLs Firebase et constantes sont hardcodées.

**Solution** : Utiliser `--dart-define` ou un fichier `.env` (via `flutter_dotenv`) pour gérer dev/staging/prod.

---

## Résumé des priorités

| Priorité | Amélioration | Impact |
|---|---|---|
| 🔴 P0 | Fusionner les modèles dupliqués | Réduction ~600 lignes, maintenabilité |
| 🔴 P0 | Supprimer les doubles repositories | Éliminer les bugs d'incohérence |
| 🔴 P0 | Supprimer les emails admin du code | Sécurité critique |
| 🔴 P0 | Nettoyer les print() de debug | Sécurité en production |
| 🔴 P0 | Résoudre les providers dupliqués | Stabilité de l'app |
| 🟡 P1 | Pagination Firestore | Performance, coûts Firebase |
| 🟡 P1 | Tests unitaires | Fiabilité |
| 🟡 P1 | Routing déclaratif (go_router) | Maintenabilité, deep links |
| 🟡 P1 | Découper les fichiers > 1000 lignes | Maintenabilité |
| 🟢 P2 | Support offline | UX en RDC (réseau instable) |
| 🟢 P2 | Paiement mobile (M-Pesa) | Monétisation |
| 🟢 P2 | Animations et transitions | UX polish |
