# Design — Pipeline Apify, sélecteur d'adresse, panneau lieu des reels

**Date** : 2026-07-19
**Statut** : implémenté (voir `docs/superpowers/plans/2026-07-19-apify-address-reels.md`) — reste à déployer les Cloud Functions et les secrets (Task 7, étape 5 du plan) avant utilisation en production.

## Contexte

Kin Experience (package `cityguide`) est un city-guide Flutter/Firebase pour Kinshasa.
Trois évolutions sont demandées :

- **A.** Automatiser les imports de données Apify (Google Places Crawler) aujourd'hui faits à la main via `scripts/apify_import/`, avec contrôle CRUD complet côté admin.
- **B.** Refondre le sélecteur d'adresse des formulaires admin (carte, saisie, suggestions, confirmation).
- **C.** Dans les reels, au tap sur le lieu lié, afficher un panneau avec description, photos, mini-carte et itinéraire.

### Découvertes importantes sur l'existant

- L'app utilise désormais une **collection unifiée `places`** (champ `categoryKey`, drapeau `isDraft`) via `lib/services/places_repository.dart`. Les 6 collections historiques (`restaurants`, `hotels`, `sites`, …) ne sont plus lues par le client. Le script `scripts/apify_import/` écrit dans les anciennes collections : il est obsolète.
- Les catégories sont dynamiques : collection Firestore `categories` (`CategoryConfig` : `key`, `label` fr/en, `fields`, …), lue par `CategoriesService`.
- Le workflow brouillons existe : `places` où `isDraft == true`, écran `lib/views/admin/contents/drafts_screen.dart`, publication = `isDraft: false`.
- `AddressLocationPicker` (`lib/views/widgets/address_location_picker.dart`, 513 lignes, inline) offre déjà recherche Nominatim, saisie manuelle géocodée, carte Google Maps avec tap/marqueur déplaçable, position actuelle. Utilisé par `add_content_form.dart` et `edit_content_form.dart`.
- `Reel` (`lib/models/reel.dart`) porte déjà `placeId`, `placeCategory`, `placeName` ; le tap actuel (`_navigateToPlace`, `reels_screen.dart`) affiche un SnackBar placeholder.
- `DetailScreen` prend un objet `Place` complet. `PlacesRepository.fetchById(id)` existe.
- `url_launcher` est déjà en dépendance. `google_maps_flutter` aussi.
- Décisions utilisateur : déclenchement = bouton admin + webhook Apify ; validation = brouillons ; catégories = restaurants, hôtels, sites, business + shopping ; config du run = catégorie + zone pré-remplies avec champ avancé optionnel ; reels = panneau complet + itinéraire Google Maps externe + lien fiche détail.

---

## Volet A — Pipeline d'import Apify

### Architecture

```
Admin Flutter ──(onCall)──▶ startApifyImport ──(API Apify)──▶ run de l'actor
                                   │                              │
                                   ▼                              │ webhook fin de run
                        doc de suivi `apify_imports`              ▼
                                   ▲                        apifyWebhook (HTTP)
                                   │                              │
                              mise à jour statut ◀────────────────┤
                                                                  ▼
                                                    mapping → écriture `places`
                                                    (nouveaux → isDraft:true,
                                                     existants publiés → merge)
```

Tout le code serveur vit dans le codebase Cloud Functions existant `functions/` (Node, gen-2). Le codebase `yes/` n'est pas touché.

### Cloud Function `startApifyImport` (onCall)

- **Auth** : requiert un utilisateur authentifié dont `users/{uid}.role == 'admin'` ou `isAdmin == true` (vérifié côté serveur, pas seulement côté client).
- **Entrée** : `{ categoryKey, commune?, customQuery?, maxItems }`.
  - `categoryKey` : une clé de la collection `categories` (restaurants, hôtels, sites, business, shopping — selon les clés réelles en base).
  - `commune` : optionnelle, une commune de Kinshasa (Gombe, Lingwala, …).
  - `customQuery` : champ avancé optionnel qui remplace la requête générée.
  - `maxItems` : plafond de résultats (défaut 50, max 200) — contrôle du coût Apify.
- **Comportement** :
  1. Construit la requête de recherche : `customQuery` si fourni, sinon `"<terme catégorie> <commune> Kinshasa"`.
  2. Démarre le run de l'actor Apify Google Places Crawler (`compass/crawler-google-places`) via l'API REST Apify, avec `webhooks` configurés sur l'événement `ACTOR.RUN.SUCCEEDED` (et `FAILED`/`ABORTED`/`TIMED_OUT` pour marquer l'échec) pointant vers `apifyWebhook`, en incluant un jeton secret dans le payload du webhook.
  3. Crée un document `apify_imports/{runId}` : `{ runId, actorId, categoryKey, query, commune, maxItems, status: 'running', startedAt, startedBy, counts: null, error: null }`.
- **Secrets** : `APIFY_TOKEN` et `APIFY_WEBHOOK_SECRET` via `defineSecret` (Firebase Secrets Manager). Jamais dans le code ni dans le client.

### Cloud Function `apifyWebhook` (onRequest)

- Vérifie le jeton secret du payload ; rejette (401) sinon.
- Idempotente : si le doc `apify_imports/{runId}` est déjà en statut terminal, ne refait rien (Apify peut rejouer un webhook).
- Sur échec du run : `status: 'failed'` + message.
- Sur succès :
  1. Télécharge les items du dataset du run (pagination par lots).
  2. **Mapping** (port du `mapper.js` existant, adapté au modèle `Place` unifié) :
     - `title → nom`, `description/categoryName → description`, `totalScore → rating`, `location.lat/lng → latitude/longitude`, `imageUrls (max 5) → photos`, `price → prixRange`, `address`, `phone`, `website`, `openingHours → schedule`, `reviewsCount → reviewCount`, `socialMedia.facebook/instagram → facebookUrl/instagramUrl`, `additionalInfo → amenities`.
     - Champs ajoutés : `categoryKey` (celui du run), `source: 'apify'`, `sourcePlaceId` (placeId Google), `importedAt`, `importRunId`.
     - Items ignorés : sans nom ou sans coordonnées GPS.
  3. **Écriture dans `places`** par lots (batched writes, ≤ 500 ops) :
     - ID du document = `placeId` Google Maps → dédoublonnage garanti entre runs.
     - Document inexistant → création avec `isDraft: true` (invisible des utilisateurs tant que non publié).
     - Document existant avec `isDraft: true` → merge (le brouillon est rafraîchi).
     - Document existant publié (`isDraft: false`) → merge **sans toucher** `isDraft`, `isFeatured`, ni les champs édités à la main quand la valeur Apify est vide.
  4. Met à jour `apify_imports/{runId}` : `{ status: 'done', finishedAt, counts: { fetched, created, updated, skipped } }`.

### Écran admin « Imports Apify »

Nouveau : `lib/views/admin/imports/apify_imports_screen.dart` (+ formulaire de lancement), entrée ajoutée dans le shell `admin_screen.dart`.

- **Formulaire de lancement** : dropdown catégorie (depuis `CategoriesService`, limité aux clés supportées par le mapping), dropdown commune de Kinshasa (liste locale des 24 communes, + « Toute la ville »), champ avancé repliable « Requête personnalisée », champ « Nombre max de résultats » avec note sur le coût Apify. Bouton « Lancer l'import » → appelle `startApifyImport`, affiche confirmation/erreur.
- **Historique des runs** : `StreamProvider` Riverpod sur `apify_imports` trié par `startedAt` desc : statut (en cours / terminé / échec) avec pastille de couleur, requête, compteurs créés/mis à jour/ignorés, horodatage. Pull-to-refresh inutile (stream temps réel).
- **Lien « Valider les brouillons »** vers `DraftsScreen` existant.
- **CRUD** : aucune duplication — la relecture/édition/suppression/publication des données importées passe par les écrans existants (brouillons + liste de contenus), qui opèrent déjà sur `places`.

### Contrôleur

`lib/controllers/apify_import_controller.dart` : `apifyImportsProvider` (StreamProvider sur `apify_imports`), fonction d'appel de la Cloud Function via `cloud_functions` (dépendance à ajouter si absente).

### Règles Firestore

`apify_imports` : lecture réservée aux admins, écriture réservée au serveur (Functions passent outre les règles ; le client n'écrit jamais dedans).

### Nettoyage

- `scripts/apify_import/` : README mis à jour pour le marquer déprécié au profit du pipeline (le dossier reste comme référence).
- Les triggers FCM `onNewSite/…` écoutent d'anciennes collections mortes — hors périmètre, mais un trigger `onNewPlacePublished` sur `places` pourra être ajouté plus tard (noté, non inclus).

### Gestion d'erreurs

- Run Apify échoué → statut `failed` visible dans l'admin avec le message.
- Webhook reçu pour un run inconnu → doc de suivi créé a posteriori avec statut approprié (robustesse).
- Item malformé → ignoré et compté dans `skipped`, jamais d'interruption du lot.

---

## Volet B — Refonte du sélecteur d'adresse

### Parcours

1. **Dans le formulaire** : `AddressField` (nouveau widget compact) — affiche l'adresse sélectionnée (ou « Choisir une adresse »), une mini-carte statique de confirmation quand des coordonnées existent, et ouvre le sélecteur plein écran au tap.
2. **Plein écran** : `AddressPickerScreen` (nouvelle page, retourne un résultat via `Navigator.pop`) :
   - Grande carte Google Maps (centre par défaut : Kinshasa) avec marqueur déplaçable + tap pour placer.
   - Barre de recherche en overlay avec suggestions combinées (voir ci-dessous), debounce 500 ms.
   - Bouton « Ma position » (géolocalisation, permissions gérées comme aujourd'hui).
   - Déplacement du marqueur → géocodage inverse automatique (Nominatim) pour remplir l'adresse, éditable à la main ensuite.
   - Barre de confirmation en bas : adresse résolue + coordonnées, bouton « Confirmer cette adresse » (désactivé tant qu'aucune position n'est choisie).
3. **Résultat** : `AddressPickResult { address, latitude, longitude }` renvoyé au formulaire.

### Suggestions combinées

`AddressSuggestionsService` (nouveau, dans `lib/services/`) fusionne trois sources, avec badge de provenance dans l'UI :

1. **Communes/quartiers de Kinshasa** : liste statique locale (24 communes + quartiers principaux, coordonnées approximatives) — instantané, hors-ligne, compense la couverture OSM.
2. **Lieux existants en base** : recherche par préfixe sur `places` publiés (champ `nom`) — permet « près de chez Untel » et réutilise des adresses déjà validées.
3. **Nominatim** : service existant (`GeocodingService.searchAddresses`, `countrycodes=cd`), inchangé.

### Déploiement dans les formulaires

- `add_content_form.dart` et `edit_content_form.dart` : remplacement de l'`AddressLocationPicker` inline par `AddressField`.
- `add_reel_form.dart` : le champ texte libre `location` gagne un bouton optionnel « Choisir sur la carte » utilisant le même sélecteur (adresse seule, coordonnées ignorées pour l'instant car `Reel` n'en stocke pas — le lieu lié fournit déjà les siennes).
- Les formulaires pubs (`ads`) n'ont pas de champ adresse : rien à faire.
- L'ancien `address_location_picker.dart` est supprimé une fois les remplacements faits (pas de code mort).

### Gestion d'erreurs

- Nominatim injoignable → suggestions locales continuent de fonctionner ; message discret « recherche en ligne indisponible ».
- Permission de localisation refusée → le bouton « Ma position » affiche un message, le reste du parcours fonctionne.

---

## Volet C — Panneau lieu dans les reels

### Comportement

Dans `reels_screen.dart`, `_navigateToPlace` est remplacé : si `reel.hasLinkedPlace`, ouverture d'un **bottom sheet glissable** (`showModalBottomSheet` + `DraggableScrollableSheet`, ~55 % de hauteur initiale, extensible) ; la vidéo continue de jouer derrière le panneau (comportement identique au sheet de commentaires existant).

Nouveau widget : `lib/views/reels/widgets/reel_place_sheet.dart`.

### Contenu du panneau

- **Chargement** : `FutureProvider.family` (ou fetch direct) via `PlacesRepository.fetchById(reel.placeId)` ; squelette de chargement pendant le fetch.
- **En-tête** : nom du lieu, chip catégorie (label localisé via `CategoryConfig`), note (étoiles + `reviewCount`) si disponible.
- **Description** : texte tronqué à 4 lignes avec « Voir plus » inline.
- **Photos** : carrousel horizontal (`AppNetworkImage`, conformément aux conventions du projet) ; masqué si aucune photo.
- **Mini-carte** : `GoogleMap` en `liteModeEnabled` (Android) / carte non interactive avec marqueur, ~160 px de haut ; masquée si coordonnées absentes (0,0 traité comme absent).
- **Actions** :
  - « S'y rendre » (bouton principal) → `url_launcher` vers `https://www.google.com/maps/dir/?api=1&destination=<lat>,<lng>` (fallback : recherche par nom si pas de coordonnées).
  - « Voir la fiche complète » → `Navigator.push` vers `DetailScreen(place: place)` (la vidéo se met en pause via le cycle de vie existant).

### Cas limites

- `placeId` absent ou lieu introuvable/supprimé → panneau avec message « Lieu indisponible » + bouton fermer (remplace le SnackBar actuel).
- Lieu en brouillon (`isDraft: true`) → traité comme introuvable pour les non-admins (le fetch filtre).

---

## Tests

- **Functions** : tests unitaires du mapper (item Apify complet, item minimal, item sans GPS ignoré, merge sans écraser `isFeatured`) avec le framework de test existant du dossier `functions/` (à défaut, tests Node natifs `node:test`).
- **Flutter** : tests widget pour `AddressField` (affichage vide / rempli), `AddressSuggestionsService` (fusion des sources, avec fakes), `ReelPlaceSheet` (états chargement / succès / introuvable) avec `ProviderScope` overrides et fakes Firestore (pattern à établir — le projet n'a que le test scaffold par défaut).
- `flutter analyze` sans nouvelle erreur.

## Hors périmètre (explicitement)

- Refonte des triggers FCM vers la collection `places`.
- Import Apify pour les événements (`events`) — les événements Google Places sont peu fiables.
- Planification automatique (cron) des runs Apify — pourra s'ajouter plus tard sur la même base webhook.
- Stockage de coordonnées GPS propres dans `Reel`.

## Ordre d'implémentation suggéré

1. Volet C (panneau reels) — isolé, valeur immédiate, aucun impact serveur.
2. Volet B (sélecteur d'adresse) — isolé côté client.
3. Volet A (pipeline Apify) — le plus gros, nécessite déploiement Functions + secrets.
