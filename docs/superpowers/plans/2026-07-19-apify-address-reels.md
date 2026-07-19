# Plan d'implémentation — Pipeline Apify, sélecteur d'adresse, panneau lieu reels

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implémenter la spec `docs/superpowers/specs/2026-07-19-apify-import-address-reels-design.md` : panneau lieu dans les reels (C), sélecteur d'adresse plein écran (B), pipeline d'import Apify automatisé (A).

**Architecture:** Client Flutter (Riverpod, collection unifiée `places`) + Cloud Functions gen-2 (`functions/`, Node 24, région `europe-west1`). Ordre d'exécution : C → B → A.

**Tech Stack:** Flutter, flutter_riverpod, cloud_firestore, cloud_functions (^6.0.6 déjà présent), google_maps_flutter, url_launcher, geolocator ; Node 24, firebase-functions v7, firebase-admin v13, API REST Apify.

## Global Constraints

- Package Dart : `cityguide` (imports `package:cityguide/...`). Ne pas renommer.
- UI et commentaires en **français**.
- Collection unifiée `places` (`categoryKey`, `isDraft`) — jamais les anciennes collections `restaurants`/`hotels`/etc.
- État : Riverpod à la main (`StateNotifier` via `flutter_riverpod/legacy.dart` si besoin), pas de GetX, pas de codegen.
- Navigation : `Navigator.push` + `MaterialPageRoute` uniquement.
- Images réseau : widget existant `AppNetworkImage` (`lib/views/widgets/app_network_image.dart`).
- Vert principal : `Color(0xFF0B7A4A)` (utilisé dans reels/admin) ; thème M3.
- Functions : région `europe-west1` (`setGlobalOptions` déjà en place), style CommonJS `require`, ESLint config google.
- Secrets serveur via `defineSecret` — jamais de token dans le code ni le client.
- Après chaque tâche : `flutter analyze` (ou `npm run lint` côté functions) sans nouvelle erreur, puis commit.
- Messages de commit : suffixe `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

## Phase C — Panneau lieu dans les reels

### Task 1: Provider + widget `ReelPlaceSheet`

**Files:**
- Create: `lib/views/reels/widgets/reel_place_sheet.dart`
- Modify: `lib/controllers/places_controller.dart` (ajout d'un provider)
- Test: `test/reel_place_sheet_test.dart`

**Interfaces:**
- Consomme : `placesRepositoryProvider` (`lib/controllers/places_controller.dart:13`), `PlacesRepository.fetchById(String id) → Future<Place?>`, `Place` (`lib/models/place.dart`), `AppNetworkImage`.
- Produit : `reelPlaceProvider` = `FutureProvider.family<Place?, String>` ; `class ReelPlaceSheet extends ConsumerWidget` avec constructeur `ReelPlaceSheet({required String placeId, String? fallbackName})` ; helper statique `ReelPlaceSheet.show(BuildContext context, {required String placeId, String? fallbackName})`.

- [ ] **Step 1 : provider dans `places_controller.dart`**

```dart
/// Lieu lié à un reel. Renvoie null si absent ou encore en brouillon
/// (un brouillon ne doit pas être visible depuis un reel public).
final reelPlaceProvider =
    FutureProvider.autoDispose.family<Place?, String>((ref, placeId) async {
  final repo = ref.watch(placesRepositoryProvider);
  final place = await repo.fetchById(placeId);
  if (place == null) return null;
  final isDraft = place.extras['isDraft'] == true;
  return isDraft ? null : place;
});
```

Note : vérifier comment `Place.fromMap` range `isDraft` (champ direct ou `extras`) et adapter la lecture — le filtre doit fonctionner réellement, pas silencieusement toujours-null.

- [ ] **Step 2 : test widget en échec**

```dart
// test/reel_place_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cityguide/controllers/places_controller.dart';
import 'package:cityguide/models/place.dart';
import 'package:cityguide/views/reels/widgets/reel_place_sheet.dart';

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        home: Scaffold(body: ReelPlaceSheet(placeId: 'p1')),
      ),
    );

void main() {
  testWidgets('affiche le nom et la description du lieu', (tester) async {
    final place = Place(
      id: 'p1',
      categoryKey: 'restaurants',
      nom: 'Chez Ntemba',
      description: 'Le meilleur poulet de la Gombe.',
      rating: 4.5,
      latitude: 0, // 0,0 => mini-carte masquée (pas de platform view en test)
      longitude: 0,
      photos: const [],
      prixRange: '',
      isFeatured: false,
    );
    final c = ProviderContainer(overrides: [
      reelPlaceProvider('p1').overrideWith((ref) async => place),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.text('Chez Ntemba'), findsOneWidget);
    expect(find.textContaining('poulet'), findsOneWidget);
    expect(find.text("S'y rendre"), findsOneWidget);
  });

  testWidgets('lieu introuvable => message dédié', (tester) async {
    final c = ProviderContainer(overrides: [
      reelPlaceProvider('p1').overrideWith((ref) async => null),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.text('Lieu indisponible'), findsOneWidget);
  });
}
```

(Adapter le constructeur de `Place` aux paramètres réels du modèle.)

- [ ] **Step 3 : lancer le test → échec attendu** (`flutter test test/reel_place_sheet_test.dart`, erreur : fichier/classe inexistants)

- [ ] **Step 4 : implémenter `ReelPlaceSheet`**

Contenu (dans une `DraggableScrollableSheet` via `ReelPlaceSheet.show` : `showModalBottomSheet(isScrollControlled: true, backgroundColor: Colors.transparent, ...)`, taille initiale 0.55, min 0.35, max 0.92, coins arrondis 24, fond `Theme.of(context).colorScheme.surface`) :

1. Poignée de drag (Container 40×4, gris arrondi).
2. `ref.watch(reelPlaceProvider(placeId))` → `.when(loading / error / data)`.
   - loading : 3 blocs `Container` gris animés simples (pas de package shimmer).
   - error ou data == null : icône `Icons.location_off`, texte « Lieu indisponible », sous-texte avec `fallbackName` si fourni, bouton « Fermer ».
   - data : colonne scrollable (le `ScrollController` de la DraggableScrollableSheet) :
     - Ligne titre : `place.nom` (titleLarge bold) + chip `place.categoryKey` (label brut, Chip compact).
     - Si `place.rating > 0` : `Icons.star` ambre + `place.rating.toStringAsFixed(1)` + `(${place.reviewCount} avis)` si > 0.
     - Si `place.address` non vide : ligne `Icons.place` + adresse.
     - Description : `Text` maxLines 4 + bouton texte « Voir plus » qui passe maxLines à null (setState local via `StatefulBuilder` ou widget interne).
     - Photos : si non vide, `SizedBox(height: 110)` + `ListView.separated` horizontal d'`AppNetworkImage` arrondies (140×110).
     - Mini-carte : uniquement si `place.latitude != 0 || place.longitude != 0` → `SizedBox(height: 160)` + `GoogleMap` (`liteModeEnabled: true`, gestures désactivés, un `Marker` sur le lieu, `initialCameraPosition` zoom 15) dans `ClipRRect`.
     - Boutons : `FilledButton.icon` « S'y rendre » (Icons.directions) pleine largeur, couleur `Color(0xFF0B7A4A)` → `_openDirections(place)` ; `OutlinedButton` « Voir la fiche complète » → `Navigator.push` vers `DetailScreen(place: place)`.

```dart
Future<void> _openDirections(Place place) async {
  final hasCoords = place.latitude != 0 || place.longitude != 0;
  final uri = hasCoords
      ? Uri.parse('https://www.google.com/maps/dir/?api=1'
          '&destination=${place.latitude},${place.longitude}')
      : Uri.parse('https://www.google.com/maps/search/?api=1'
          '&query=${Uri.encodeComponent('${place.nom} Kinshasa')}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
```

- [ ] **Step 5 : test → PASS**, `flutter analyze` propre
- [ ] **Step 6 : commit** `feat(reels): panneau lieu (ReelPlaceSheet) + provider reelPlaceProvider`

### Task 2: Intégration dans `reels_screen.dart`

**Files:**
- Modify: `lib/views/reels/reels_screen.dart:435-453` (`_navigateToPlace`)

**Interfaces:**
- Consomme : `ReelPlaceSheet.show` (Task 1), `Reel.hasLinkedPlace`, `reel.placeId`, `reel.placeName`.

- [ ] **Step 1 : remplacer le corps de `_navigateToPlace`**

```dart
void _navigateToPlace(Reel reel) {
  if (!reel.hasLinkedPlace) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aucun lieu lié à ce reel')),
    );
    return;
  }
  ReelPlaceSheet.show(
    context,
    placeId: reel.placeId!,
    fallbackName: reel.placeName ?? reel.location,
  );
}
```

- [ ] **Step 2 : `flutter analyze` propre, tests OK**
- [ ] **Step 3 : commit** `feat(reels): ouvre le panneau lieu au tap sur la localisation`

---

## Phase B — Sélecteur d'adresse plein écran

### Task 3: Données communes + `AddressSuggestionsService`

**Files:**
- Create: `lib/data/kinshasa_zones.dart`
- Create: `lib/services/address_suggestions_service.dart`
- Modify: `lib/services/geocoding_service.dart` (ajout champ `source` sur `AddressSuggestion`)
- Test: `test/address_suggestions_service_test.dart`

**Interfaces:**
- Produit :
  - `class KinshasaZone { final String nom; final double latitude; final double longitude; }` + `const List<KinshasaZone> kinshasaZones` (24 communes).
  - `AddressSuggestion` gagne `final String source;` (valeurs : `'zone' | 'place' | 'osm'`, défaut `'osm'`).
  - `class AddressSuggestionsService { AddressSuggestionsService({GeocodingService? geocoding, Future<List<AddressSuggestion>> Function(String query)? placesSearch}); Future<List<AddressSuggestion>> search(String query); }`
  - Ordre du résultat : zones locales, puis lieux en base, puis Nominatim ; max ~12 ; jamais d'exception (une source qui échoue est ignorée).

- [ ] **Step 1 : `kinshasa_zones.dart`** — les 24 communes avec coordonnées approximatives du centre :

```dart
class KinshasaZone {
  final String nom;
  final double latitude;
  final double longitude;
  const KinshasaZone(this.nom, this.latitude, this.longitude);
}

const List<KinshasaZone> kinshasaZones = [
  KinshasaZone('Bandalungwa', -4.3439, 15.2831),
  KinshasaZone('Barumbu', -4.3103, 15.3231),
  KinshasaZone('Bumbu', -4.3833, 15.2833),
  KinshasaZone('Gombe', -4.3054, 15.2938),
  KinshasaZone('Kalamu', -4.3436, 15.3125),
  KinshasaZone('Kasa-Vubu', -4.3372, 15.3006),
  KinshasaZone('Kimbanseke', -4.4167, 15.4333),
  KinshasaZone('Kinshasa (commune)', -4.3167, 15.3167),
  KinshasaZone('Kintambo', -4.3283, 15.2597),
  KinshasaZone('Kisenso', -4.4167, 15.3667),
  KinshasaZone('Lemba', -4.3894, 15.3336),
  KinshasaZone('Limete', -4.3550, 15.3383),
  KinshasaZone('Lingwala', -4.3181, 15.3006),
  KinshasaZone('Makala', -4.3833, 15.3000),
  KinshasaZone('Maluku', -4.0833, 15.5500),
  KinshasaZone('Masina', -4.3833, 15.4000),
  KinshasaZone('Matete', -4.3872, 15.3489),
  KinshasaZone('Mont-Ngafula', -4.4500, 15.2833),
  KinshasaZone('Ndjili', -4.4000, 15.3719),
  KinshasaZone('Ngaba', -4.3717, 15.3169),
  KinshasaZone('Ngaliema', -4.3500, 15.2333),
  KinshasaZone('Ngiri-Ngiri', -4.3486, 15.2958),
  KinshasaZone('Nsele', -4.3167, 15.5167),
  KinshasaZone('Selembao', -4.3667, 15.2667),
];
```

- [ ] **Step 2 : ajouter `source` à `AddressSuggestion`** (`this.source = 'osm'` dans le constructeur, non requis, sans casser les usages existants).

- [ ] **Step 3 : tests en échec**

```dart
// test/address_suggestions_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cityguide/services/address_suggestions_service.dart';
import 'package:cityguide/services/geocoding_service.dart';

class _FakeGeocoding extends GeocodingService {
  final List<AddressSuggestion> results;
  final bool shouldThrow;
  _FakeGeocoding(this.results, {this.shouldThrow = false});
  @override
  Future<List<AddressSuggestion>> searchAddresses(String query) async {
    if (shouldThrow) throw Exception('réseau');
    return results;
  }
}

void main() {
  test('les communes matchent par préfixe insensible à la casse', () async {
    final svc = AddressSuggestionsService(
      geocoding: _FakeGeocoding(const []),
      placesSearch: (_) async => const [],
    );
    final out = await svc.search('gom');
    expect(out.first.displayName, contains('Gombe'));
    expect(out.first.source, 'zone');
  });

  test('fusion : zones puis lieux puis osm', () async {
    final svc = AddressSuggestionsService(
      geocoding: _FakeGeocoding(const [
        AddressSuggestion(displayName: 'Gombe OSM', latitude: 1, longitude: 2),
      ]),
      placesSearch: (_) async => const [
        AddressSuggestion(
            displayName: 'Restaurant Gombe Grill',
            latitude: 3, longitude: 4, source: 'place'),
      ],
    );
    final out = await svc.search('gombe');
    expect(out.map((s) => s.source).toList(), ['zone', 'place', 'osm']);
  });

  test('une source qui échoue est ignorée', () async {
    final svc = AddressSuggestionsService(
      geocoding: _FakeGeocoding(const [], shouldThrow: true),
      placesSearch: (_) async => throw Exception('firestore'),
    );
    final out = await svc.search('gombe');
    expect(out, isNotEmpty); // la zone Gombe reste
  });
}
```

- [ ] **Step 4 : implémenter le service**

```dart
// lib/services/address_suggestions_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cityguide/data/kinshasa_zones.dart';
import 'package:cityguide/services/geocoding_service.dart';

/// Fusionne trois sources de suggestions d'adresses :
/// 1. communes de Kinshasa (liste locale, hors-ligne),
/// 2. lieux déjà publiés dans `places` (préfixe sur `nom`),
/// 3. Nominatim (OpenStreetMap).
class AddressSuggestionsService {
  final GeocodingService _geocoding;
  final Future<List<AddressSuggestion>> Function(String query) _placesSearch;

  AddressSuggestionsService({
    GeocodingService? geocoding,
    Future<List<AddressSuggestion>> Function(String query)? placesSearch,
  })  : _geocoding = geocoding ?? GeocodingService(),
        _placesSearch = placesSearch ?? _defaultPlacesSearch;

  Future<List<AddressSuggestion>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final zones = _searchZones(q);
    final results = await Future.wait([
      _safe(() => _placesSearch(q)),
      _safe(() => _geocoding.searchAddresses(q)),
    ]);

    return [...zones, ...results[0].take(4), ...results[1].take(5)]
        .take(12)
        .toList();
  }

  List<AddressSuggestion> _searchZones(String q) {
    final lower = q.toLowerCase();
    return kinshasaZones
        .where((z) => z.nom.toLowerCase().contains(lower))
        .take(3)
        .map((z) => AddressSuggestion(
              displayName: '${z.nom}, Kinshasa',
              latitude: z.latitude,
              longitude: z.longitude,
              city: 'Kinshasa',
              suburb: z.nom,
              source: 'zone',
            ))
        .toList();
  }

  static Future<List<AddressSuggestion>> _defaultPlacesSearch(
      String query) async {
    final cap = query[0].toUpperCase() + query.substring(1);
    final snap = await FirebaseFirestore.instance
        .collection('places')
        .where('isDraft', isEqualTo: false)
        .where('nom', isGreaterThanOrEqualTo: cap)
        .where('nom', isLessThan: '$cap')
        .limit(4)
        .get();
    return snap.docs
        .map((d) {
          final data = d.data();
          final lat = (data['latitude'] as num?)?.toDouble() ?? 0;
          final lng = (data['longitude'] as num?)?.toDouble() ?? 0;
          if (lat == 0 && lng == 0) return null;
          return AddressSuggestion(
            displayName:
                '${data['nom']}${data['address'] != null ? ' — ${data['address']}' : ''}',
            latitude: lat,
            longitude: lng,
            source: 'place',
          );
        })
        .whereType<AddressSuggestion>()
        .toList();
  }

  Future<List<AddressSuggestion>> _safe(
      Future<List<AddressSuggestion>> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return [];
    }
  }
}
```

- [ ] **Step 5 : `flutter test test/address_suggestions_service_test.dart` → PASS**, analyze propre
- [ ] **Step 6 : commit** `feat(adresse): service de suggestions combinées (communes + lieux + OSM)`

### Task 4: `AddressPickerScreen` + `AddressField`

**Files:**
- Create: `lib/views/widgets/address_picker_screen.dart`
- Create: `lib/views/widgets/address_field.dart`

**Interfaces:**
- Produit :
  - `class AddressPickResult { final String address; final double latitude; final double longitude; }`
  - `AddressPickerScreen({String? initialAddress, double? initialLatitude, double? initialLongitude})` → poppé avec un `AddressPickResult?`.
  - `AddressField({String? address, double? latitude, double? longitude, required ValueChanged<AddressPickResult> onChanged, String label = 'Adresse'})`.
- Consomme : `AddressSuggestionsService` (Task 3), `GeocodingService.reverseGeocode/getCurrentPosition`, `google_maps_flutter`.

- [ ] **Step 1 : `AddressPickerScreen`** — `StatefulWidget`, Scaffold plein écran :
  - `GoogleMap` plein écran (`initialCameraPosition` : coordonnées initiales sinon centre Kinshasa `LatLng(-4.3276, 15.3136)` zoom 12), `onTap: _setMarker`, marqueur unique `draggable: true` avec `onDragEnd: _setMarker`, `myLocationEnabled: true`, `myLocationButtonEnabled: false`.
  - `_setMarker(LatLng pos)` : met à jour le marqueur, anime la caméra, puis géocodage inverse async → remplit `_addressController.text` (sauf si l'utilisateur a modifié le champ à la main depuis — flag `_addressEdited` remis à false à chaque nouveau marqueur).
  - En haut (SafeArea) : Card avec `TextField` de recherche (debounce 500 ms → `AddressSuggestionsService.search`) ; sous le champ, liste des suggestions avec icône par source (`zone` → `Icons.location_city`, `place` → `Icons.storefront`, `osm` → `Icons.public`) ; tap = `_setMarker` + fermeture de la liste.
  - FAB `Icons.my_location` → `GeocodingService.getCurrentPosition()` ; si null : SnackBar « Position indisponible — vérifiez les autorisations », sinon `_setMarker`.
  - Panneau bas (Card) : `TextField` `_addressController` (label « Adresse affichée », éditable, `onChanged` pose `_addressEdited = true`), coordonnées en petit (`lat, lng` à 5 décimales), bouton `FilledButton` « Confirmer cette adresse » désactivé tant que marqueur null ou adresse vide → `Navigator.pop(context, AddressPickResult(...))`.

- [ ] **Step 2 : `AddressField`** — widget de formulaire compact :
  - `InputDecorator`-style : `InkWell` ouvrant `AddressPickerScreen` (`Navigator.push<AddressPickResult>`), affiche l'adresse ou « Choisir une adresse… » en placeholder, icône `Icons.map_outlined` à droite.
  - Si coordonnées non nulles : sous le champ, ligne de confirmation `Icons.check_circle` vert + `'Position GPS : lat, lng'`.
  - Au retour non-null : `onChanged(result)`.

- [ ] **Step 3 : `flutter analyze` propre** (pas de test widget : GoogleMap = platform view non testable en `flutter test` ; la logique testable vit dans le service Task 3 ; vérification manuelle en Task 5)
- [ ] **Step 4 : commit** `feat(adresse): sélecteur plein écran + champ de formulaire AddressField`

### Task 5: Branchement dans les formulaires + suppression de l'ancien widget

**Files:**
- Modify: `lib/views/admin/contents/add_content_form.dart:499-510` (et imports, ligne 11)
- Modify: `lib/views/admin/contents/edit_content_form.dart:349-360` (et imports, ligne 13)
- Modify: `lib/views/admin/reels/add_reel_form.dart` (champ `location`)
- Delete: `lib/views/widgets/address_location_picker.dart`

- [ ] **Step 1 : add_content_form** — remplacer le bloc `AddressLocationPicker(...)` par :

```dart
AddressField(
  address: _addressController.text.isEmpty ? null : _addressController.text,
  latitude: double.tryParse(_latitudeController.text),
  longitude: double.tryParse(_longitudeController.text),
  onChanged: (r) {
    setState(() {
      _addressController.text = r.address;
      _latitudeController.text = r.latitude.toString();
      _longitudeController.text = r.longitude.toString();
    });
  },
),
```

Import : `package:cityguide/views/widgets/address_field.dart` (retirer l'ancien import).

- [ ] **Step 2 : edit_content_form** — même remplacement (mêmes contrôleurs).
- [ ] **Step 3 : add_reel_form** — à côté du `TextField` `_locationController`, `IconButton(Icons.map_outlined)` qui pousse `AddressPickerScreen` et, au retour, pose `_locationController.text = result.address` (coordonnées ignorées, `Reel` n'en stocke pas).
- [ ] **Step 4 : supprimer `address_location_picker.dart`**, vérifier `grep -rn "AddressLocationPicker" lib/` → aucun résultat.
- [ ] **Step 5 : `flutter analyze` propre + `flutter test`** ; vérification manuelle rapide sur simulateur si disponible.
- [ ] **Step 6 : commit** `feat(adresse): tous les formulaires utilisent le nouveau sélecteur ; suppression de l'ancien widget`

---

## Phase A — Pipeline d'import Apify

### Task 6: Mapper Apify → `Place` (functions) + tests

**Files:**
- Create: `functions/apify/mapper.js`
- Test: `functions/apify/mapper.test.js`
- Modify: `functions/package.json` (script `"test": "node --test apify/"`)

**Interfaces:**
- Produit : `mapApifyItem(item, { categoryKey, runId }) → { docId, data } | null` (null si item invalide : sans nom ou sans GPS). `docId` = `item.placeId`. `data` = champs du modèle `Place` unifié + `categoryKey`, `source: 'apify'`, `sourcePlaceId`, `importRunId`, SANS `isDraft` (décidé à l'écriture).

- [ ] **Step 1 : tests en échec** (`node --test apify/`)

```js
// functions/apify/mapper.test.js
const test = require("node:test");
const assert = require("node:assert");
const {mapApifyItem} = require("./mapper");

const fullItem = {
  placeId: "ChIJabc123",
  title: "Chez Ntemba",
  description: "Grill réputé",
  categoryName: "Restaurant",
  totalScore: 4.4,
  reviewsCount: 120,
  location: {lat: -4.30, lng: 15.29},
  imageUrls: ["https://a.jpg", "https://b.jpg", "https://c.jpg",
    "https://d.jpg", "https://e.jpg", "https://f.jpg"],
  price: "$$",
  address: "Av. du Port, Gombe",
  phone: "+243 81 000 0000",
  website: "https://ntemba.cd",
  openingHours: [{day: "Monday", hours: "9AM–10PM"}],
  socialMedia: {facebook: "https://fb.com/ntemba"},
  additionalInfo: {"Options": [{"Terrasse": true}, {"Wifi": false}]},
};

test("item complet mappé vers le format Place", () => {
  const out = mapApifyItem(fullItem, {categoryKey: "restaurants", runId: "r1"});
  assert.strictEqual(out.docId, "ChIJabc123");
  const d = out.data;
  assert.strictEqual(d.nom, "Chez Ntemba");
  assert.strictEqual(d.categoryKey, "restaurants");
  assert.strictEqual(d.rating, 4.4);
  assert.strictEqual(d.latitude, -4.30);
  assert.strictEqual(d.photos.length, 5); // plafonné à 5
  assert.strictEqual(d.prixRange, "Modéré");
  assert.deepStrictEqual(d.amenities, ["Terrasse"]); // false exclu
  assert.strictEqual(d.schedule, "Monday: 9AM–10PM");
  assert.strictEqual(d.source, "apify");
  assert.strictEqual(d.importRunId, "r1");
  assert.strictEqual(d.isDraft, undefined);
});

test("item minimal accepté, description = categoryName", () => {
  const out = mapApifyItem(
      {placeId: "x", title: "Spot", categoryName: "Bar",
        location: {lat: 1, lng: 2}},
      {categoryKey: "restaurants", runId: "r1"});
  assert.strictEqual(out.data.description, "Bar");
  assert.strictEqual(out.data.rating, 0);
});

test("item sans GPS ou sans nom => null", () => {
  assert.strictEqual(mapApifyItem({title: "SansGPS", placeId: "y"},
      {categoryKey: "restaurants", runId: "r1"}), null);
  assert.strictEqual(mapApifyItem({location: {lat: 1, lng: 2}, placeId: "z"},
      {categoryKey: "restaurants", runId: "r1"}), null);
});

test("item sans placeId => null (pas d'ID de doc stable)", () => {
  assert.strictEqual(mapApifyItem({title: "X", location: {lat: 1, lng: 2}},
      {categoryKey: "restaurants", runId: "r1"}), null);
});
```

- [ ] **Step 2 : implémenter `functions/apify/mapper.js`** — reprendre `scripts/apify_import/mapper.js` (mapPrixRange, mapSchedule, mapPhotos, mapAmenities identiques) avec ces différences :
  - signature `mapApifyItem(item, {categoryKey, runId})` retournant `{docId, data}` ou `null` ;
  - validation : `placeId` requis, nom requis, GPS requis (lat et lng non nuls) → sinon `null` ;
  - `data` inclut `categoryKey`, `source: "apify"`, `sourcePlaceId: item.placeId`, `importRunId: runId` ; plus de champs préfixés `_` ; pas de `distanceKm` ; `reviewCount: item.reviewsCount ?? 0` ;
  - style ESLint google (guillemets doubles, 2 espaces) comme `index.js`.
- [ ] **Step 3 : `cd functions && npm test` → 4 tests PASS ; `npm run lint` propre**
- [ ] **Step 4 : commit** `feat(functions): mapper Apify vers le modèle Place unifié`

### Task 7: Functions `startApifyImport` + `apifyWebhook` + règles Firestore

**Files:**
- Create: `functions/apify/pipeline.js`
- Modify: `functions/index.js` (exports + require)
- Modify: `firestore.rules` (collection `apify_imports`)

**Interfaces:**
- Consomme : `mapApifyItem` (Task 6).
- Produit :
  - `startApifyImport` (onCall, secrets `[APIFY_TOKEN, APIFY_WEBHOOK_SECRET]`) — entrée `{categoryKey, commune?, customQuery?, maxItems?}`, sortie `{runId}`. Erreurs : `unauthenticated`, `permission-denied` (non-admin), `invalid-argument`.
  - `apifyWebhook` (onRequest, secret `APIFY_WEBHOOK_SECRET`) — reçoit le webhook Apify, importe le dataset.
  - Docs `apify_imports/{runId}` : `{runId, categoryKey, query, commune, maxItems, status: 'running'|'done'|'failed', startedAt, finishedAt, startedBy, counts: {fetched, created, updated, skipped}, error}`.

- [ ] **Step 1 : implémenter `functions/apify/pipeline.js`**

```js
// functions/apify/pipeline.js
const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const {mapApifyItem} = require("./mapper");

const APIFY_TOKEN = defineSecret("APIFY_TOKEN");
const APIFY_WEBHOOK_SECRET = defineSecret("APIFY_WEBHOOK_SECRET");

const ACTOR_ID = "compass~crawler-google-places";
const APIFY_API = "https://api.apify.com/v2";

// Libellés de recherche par catégorie (clés = collection `categories`).
const CATEGORY_SEARCH_TERMS = {
  restaurants: "restaurants",
  hotels: "hôtels",
  sites: "sites touristiques attractions",
  business: "entreprises services",
  shopping: "boutiques centres commerciaux",
};

async function assertIsAdmin(auth) {
  if (!auth) throw new HttpsError("unauthenticated", "Connexion requise");
  const snap = await admin.firestore().doc(`users/${auth.uid}`).get();
  const u = snap.data() || {};
  if (u.role !== "admin" && u.isAdmin !== true) {
    throw new HttpsError("permission-denied", "Réservé aux administrateurs");
  }
}

const startApifyImport = onCall(
    {secrets: [APIFY_TOKEN, APIFY_WEBHOOK_SECRET]},
    async (request) => {
      await assertIsAdmin(request.auth);

      const {categoryKey, commune, customQuery} = request.data || {};
      const maxItems = Math.min(Number(request.data?.maxItems) || 50, 200);
      if (!CATEGORY_SEARCH_TERMS[categoryKey]) {
        throw new HttpsError("invalid-argument",
            `Catégorie non supportée: ${categoryKey}`);
      }

      const query = (customQuery && String(customQuery).trim()) ||
          [CATEGORY_SEARCH_TERMS[categoryKey], commune, "Kinshasa"]
              .filter(Boolean).join(" ");

      const projectId = process.env.GCLOUD_PROJECT;
      const webhookUrl =
          `https://europe-west1-${projectId}.cloudfunctions.net/apifyWebhook` +
          `?secret=${APIFY_WEBHOOK_SECRET.value()}`;
      const webhooks = Buffer.from(JSON.stringify([{
        eventTypes: ["ACTOR.RUN.SUCCEEDED", "ACTOR.RUN.FAILED",
          "ACTOR.RUN.ABORTED", "ACTOR.RUN.TIMED_OUT"],
        requestUrl: webhookUrl,
      }])).toString("base64");

      const res = await fetch(
          `${APIFY_API}/acts/${ACTOR_ID}/runs?token=${APIFY_TOKEN.value()}` +
          `&webhooks=${webhooks}`,
          {
            method: "POST",
            headers: {"Content-Type": "application/json"},
            body: JSON.stringify({
              searchStringsArray: [query],
              locationQuery: "Kinshasa, Democratic Republic of the Congo",
              maxCrawledPlacesPerSearch: maxItems,
              language: "fr",
            }),
          });
      if (!res.ok) {
        throw new HttpsError("internal",
            `Apify a refusé le lancement (${res.status})`);
      }
      const run = (await res.json()).data;

      await admin.firestore().doc(`apify_imports/${run.id}`).set({
        runId: run.id,
        categoryKey, query, commune: commune || null, maxItems,
        status: "running",
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
        startedBy: request.auth.uid,
        finishedAt: null, counts: null, error: null,
      });
      return {runId: run.id};
    });

const apifyWebhook = onRequest(
    {secrets: [APIFY_TOKEN, APIFY_WEBHOOK_SECRET]},
    async (req, res) => {
      if (req.query.secret !== APIFY_WEBHOOK_SECRET.value()) {
        res.status(401).send("unauthorized");
        return;
      }
      const eventType = req.body?.eventType;
      const run = req.body?.resource;
      if (!run?.id) {
        res.status(400).send("payload invalide");
        return;
      }

      const db = admin.firestore();
      const trackRef = db.doc(`apify_imports/${run.id}`);
      const track = await trackRef.get();
      const status = track.data()?.status;
      if (status === "done" || status === "failed") {
        res.status(200).send("déjà traité"); // webhook rejoué => idempotent
        return;
      }

      if (eventType !== "ACTOR.RUN.SUCCEEDED") {
        await trackRef.set({
          status: "failed", error: `Run Apify: ${eventType}`,
          finishedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
        res.status(200).send("échec enregistré");
        return;
      }

      const categoryKey = track.data()?.categoryKey;
      if (!categoryKey) {
        await trackRef.set({
          status: "failed", error: "Run inconnu (pas de suivi)",
          finishedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
        res.status(200).send("run inconnu");
        return;
      }

      const counts = {fetched: 0, created: 0, updated: 0, skipped: 0};
      let offset = 0;
      const pageSize = 200;
      for (;;) {
        const page = await fetch(
            `${APIFY_API}/datasets/${run.defaultDatasetId}/items` +
            `?token=${APIFY_TOKEN.value()}&clean=true` +
            `&offset=${offset}&limit=${pageSize}`);
        const items = await page.json();
        if (!Array.isArray(items) || items.length === 0) break;
        counts.fetched += items.length;

        // Écritures par lots (limite batch Firestore : 500 opérations).
        let batch = db.batch();
        let ops = 0;
        for (const item of items) {
          const mapped = mapApifyItem(item, {categoryKey, runId: run.id});
          if (!mapped) {
            counts.skipped++;
            continue;
          }
          const ref = db.collection("places").doc(mapped.docId);
          const existing = await ref.get();
          const now = admin.firestore.FieldValue.serverTimestamp();
          if (!existing.exists) {
            batch.set(ref, {
              ...mapped.data, isDraft: true, isFeatured: false,
              createdAt: now, updatedAt: now,
            });
            counts.created++;
          } else {
            // Merge sans toucher isDraft/isFeatured ni écraser par du vide.
            const data = {...mapped.data, updatedAt: now};
            for (const [k, v] of Object.entries(data)) {
              const empty = v === null || v === "" ||
                  (Array.isArray(v) && v.length === 0);
              if (empty && existing.data()[k] != null) delete data[k];
            }
            batch.set(ref, data, {merge: true});
            counts.updated++;
          }
          if (++ops >= 400) {
            await batch.commit();
            batch = db.batch();
            ops = 0;
          }
        }
        if (ops > 0) await batch.commit();

        if (items.length < pageSize) break;
        offset += pageSize;
      }

      await trackRef.set({
        status: "done", counts,
        finishedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      res.status(200).send("import terminé");
    });

module.exports = {startApifyImport, apifyWebhook};
```

- [ ] **Step 2 : exporter dans `functions/index.js`** (en fin de fichier) :

```js
// ─── Import Apify ───
const {startApifyImport, apifyWebhook} = require("./apify/pipeline");
exports.startApifyImport = startApifyImport;
exports.apifyWebhook = apifyWebhook;
```

- [ ] **Step 3 : règles Firestore** — dans `firestore.rules`, ajouter (en réutilisant le helper admin existant du fichier, à vérifier à la lecture) :

```
match /apify_imports/{runId} {
  allow read: if isAdmin();
  allow write: if false; // seul le serveur écrit
}
```

- [ ] **Step 4 : `npm run lint` + `npm test` propres ; commit** `feat(functions): pipeline d'import Apify (lancement + webhook + suivi)`
- [ ] **Step 5 : instructions de déploiement** (à exécuter par l'utilisateur ou avec son accord ; noter le codebase `yes/` accidentel — déployer UNIQUEMENT `functions`) :

```bash
firebase functions:secrets:set APIFY_TOKEN          # coller le token Apify
firebase functions:secrets:set APIFY_WEBHOOK_SECRET # une chaîne aléatoire longue
firebase deploy --only functions:startApifyImport,functions:apifyWebhook
firebase deploy --only firestore:rules
```

### Task 8: Écran admin « Imports Apify »

**Files:**
- Create: `lib/models/apify_import_run.dart`
- Create: `lib/controllers/apify_import_controller.dart`
- Create: `lib/views/admin/imports/apify_imports_screen.dart`
- Modify: `lib/views/admin/admin_screen.dart` (nouvelle section de menu, à côté des lignes 220-239)
- Test: `test/apify_import_run_test.dart`

**Interfaces:**
- Consomme : `startApifyImport` (Task 7), `CategoriesService`/`categoriesServiceProvider`, `kinshasaZones` (Task 3), `DraftsScreen`.
- Produit : `ApifyImportRun.fromMap(Map, String id)` ; `apifyImportsProvider` (StreamProvider) ; `startApifyImportCall({required String categoryKey, String? commune, String? customQuery, int maxItems})`.

- [ ] **Step 1 : test modèle en échec**

```dart
// test/apify_import_run_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cityguide/models/apify_import_run.dart';

void main() {
  test('fromMap tolère les champs manquants', () {
    final run = ApifyImportRun.fromMap(const {}, 'r1');
    expect(run.id, 'r1');
    expect(run.status, 'running');
    expect(run.counts, isNull);
  });

  test('fromMap lit les compteurs', () {
    final run = ApifyImportRun.fromMap(const {
      'status': 'done',
      'query': 'restaurants Gombe Kinshasa',
      'counts': {'fetched': 10, 'created': 6, 'updated': 3, 'skipped': 1},
    }, 'r2');
    expect(run.status, 'done');
    expect(run.counts!.created, 6);
  });
}
```

- [ ] **Step 2 : modèle** — classes immuables `ApifyImportRun` (`id, categoryKey, query, commune, maxItems, status, startedAt, finishedAt, error, counts`) et `ApifyImportCounts` (`fetched, created, updated, skipped`), parsing via `ModelHelpers` (`parseInt`) et tolérant (défauts : `status: 'running'`). Test → PASS.
- [ ] **Step 3 : contrôleur**

```dart
// lib/controllers/apify_import_controller.dart
final apifyImportsProvider =
    StreamProvider.autoDispose<List<ApifyImportRun>>((ref) {
  return FirebaseFirestore.instance
      .collection('apify_imports')
      .orderBy('startedAt', descending: true)
      .limit(30)
      .snapshots()
      .map((s) => s.docs
          .map((d) => ApifyImportRun.fromMap(d.data(), d.id))
          .toList());
});

Future<String> startApifyImportCall({
  required String categoryKey,
  String? commune,
  String? customQuery,
  int maxItems = 50,
}) async {
  final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
      .httpsCallable('startApifyImport');
  final res = await callable.call<Map<String, dynamic>>({
    'categoryKey': categoryKey,
    if (commune != null) 'commune': commune,
    if (customQuery != null && customQuery.trim().isNotEmpty)
      'customQuery': customQuery.trim(),
    'maxItems': maxItems,
  });
  return (res.data['runId'] ?? '').toString();
}
```

- [ ] **Step 4 : écran** `ApifyImportsScreen` (`ConsumerStatefulWidget`) :
  - AppBar « Imports Apify » (style vert des écrans admin).
  - **Carte « Lancer un import »** : dropdown catégorie (chargée via `categoriesServiceProvider.fetchAll()`, filtrée aux clés de `CATEGORY_SEARCH_TERMS` côté client : liste locale `const ['restaurants','hotels','sites','business','shopping']` intersectée avec les catégories réelles), dropdown commune (« Toute la ville » + `kinshasaZones.map((z) => z.nom)`), `ExpansionTile` « Options avancées » contenant le champ requête personnalisée + slider/champ `maxItems` (10-200, défaut 50) avec note « Chaque lieu consomme des crédits Apify », bouton `FilledButton.icon` « Lancer l'import » → `startApifyImportCall` avec spinner, SnackBar succès (« Import lancé — les résultats arriveront en brouillons ») ou erreur (`FirebaseFunctionsException.message`).
  - **Bouton secondaire** « Valider les brouillons » → `Navigator.push` vers `DraftsScreen`.
  - **Historique** : `ref.watch(apifyImportsProvider)` → liste de Cards : pastille (orange `running` / vert `done` / rouge `failed`), requête, date (`startedAt`), et si `done` : « X créés · Y mis à jour · Z ignorés » ; si `failed` : message d'erreur.
- [ ] **Step 5 : entrée dans `admin_screen.dart`** — nouvelle section après les pubs :

```dart
_menuButton(theme, icon: Icons.cloud_download_outlined,
    label: 'Imports Apify',
    onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ApifyImportsScreen()))),
```

- [ ] **Step 6 : `flutter analyze` + `flutter test` propres ; commit** `feat(admin): écran Imports Apify (lancement + historique temps réel)`

### Task 9: Finitions

**Files:**
- Modify: `scripts/apify_import/README.md` (bandeau de dépréciation en tête)
- Modify: `docs/superpowers/specs/2026-07-19-apify-import-address-reels-design.md` (statut → implémenté)

- [ ] **Step 1 : bandeau** en tête du README : « ⚠️ DÉPRÉCIÉ — remplacé par le pipeline Cloud Functions (`functions/apify/`) piloté depuis l'écran admin “Imports Apify”. Ce script écrit dans les anciennes collections et ne doit plus être utilisé. »
- [ ] **Step 2 : `flutter analyze` + `flutter test` + `cd functions && npm test && npm run lint` — tout propre**
- [ ] **Step 3 : commit final** `chore: dépréciation du script d'import local, finitions`

---

## Auto-revue du plan

- Couverture spec : Volet C → Tasks 1-2 ; Volet B → Tasks 3-5 ; Volet A → Tasks 6-9 ; règles Firestore → Task 7 ; dépréciation script → Task 9. ✔
- Types cohérents : `AddressPickResult` produit en Task 4, consommé en Task 5 ; `mapApifyItem` produit en Task 6, consommé en Task 7 ; `reelPlaceProvider` produit en Task 1, consommé en Task 1-2. ✔
- Les points « à vérifier à la lecture » (rangement d'`isDraft` dans `Place`, helper admin des rules, paramètres exacts du constructeur `Place`) sont des adaptations locales à faire au moment de toucher le fichier, pas des inconnues de conception. ✔
