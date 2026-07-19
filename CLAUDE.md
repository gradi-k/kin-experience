# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"Kin Experience" — a Flutter city-guide app for Kinshasa (DRC) covering hotels, restaurants, sites, events, businesses, shopping, plus reels and ads. Targets Android, iOS, and Web (Firebase Hosting). The app UI, code comments, and README are primarily in **French**.

Naming gotcha: the pubspec package name is **`cityguide`** (all imports are `package:cityguide/...`), the app class is `CityGuideApp`, but the product/Firebase project is `kin-experience`. Do not rename the package. (README.md claims the package is `kin_experience` — trust the code.)

## Commands

```bash
flutter pub get                    # install deps
flutter run                        # run (pick device: -d chrome, -d <ios/android id>)
flutter analyze                    # lint (flutter_lints defaults, no custom rules)
flutter test                       # only test/widget_test.dart exists (default scaffold)
flutter test test/widget_test.dart # single test file
flutter build web                  # web build → build/web
firebase deploy --only hosting     # deploy web (serves build/web, SPA rewrite)
firebase deploy --only functions   # Cloud Functions (see warning below)
flutter pub run flutter_launcher_icons  # regenerate app icons
```

There is **no codegen** — no build_runner, freezed, json_serializable, or riverpod_generator.

⚠️ firebase.json declares two functions codebases: `functions/` (default) and `yes/` (codebase `main`, likely accidental). Verify before deploying functions.

## Architecture

Layered MVC: `lib/models/` → `lib/services/` + `lib/repositories/` → `lib/controllers/` (Riverpod providers) → `lib/views/` (screens by feature). Also `lib/themes/`, `lib/localization/`, `lib/utils/`, `lib/data/` (fake/seed data).

### Startup & auth flow (all in lib/main.dart)

`main()` initializes Firebase (guarded against duplicate app), App Check, `FirebaseAuth.setLanguageCode('fr')`, NotificationService, then `ProviderScope(child: CityGuideApp())`. Flow: `AppEntryPoint` (splash + SharedPreferences onboarding check) → `OnboardingScreen` (first launch) → `AuthGate` → auth stream → OTP verification (`isVerified` in Firestore `users`) → admin check → `AdminScreen` or `HomeScreen`.

Admin access = hardcoded email whitelist in `main.dart` (`_adminEmails`) OR `users/{uid}.role == 'admin'` / `isAdmin == true`. Note: `controllers/auth_controller.dart` has a second, shorter whitelist — the logic is duplicated.

### State management (Riverpod 3.x, hand-written)

Top-level `final xProvider = ...` globals in `lib/controllers/*` (auth, theme, places, favorites, notification, dual_auth, two_factor, location). `StateNotifier`/`StateNotifierProvider` come from `package:flutter_riverpod/legacy.dart`. Views are `ConsumerWidget`/`ConsumerStatefulWidget`. Canonical StateNotifier example: `themeModeProvider` in `controllers/theme_controller.dart`. Services expose Firestore realtime streams (e.g. `PlacesService.watchHotels()`, `fetchHotelById()`) that controllers wrap into `StreamProvider`s.

Note: `get` (GetX) is a dependency but is NOT used for state or navigation — don't introduce it.

### Navigation

Imperative `Navigator.push` + `MaterialPageRoute` only. No go_router, no named routes.

### Models

Plain immutable classes with `factory X.fromMap(Map<String, dynamic> map, String id)` + `toMap()` (Firestore-doc oriented). All field parsing goes through `lib/models/model_helpers.dart` (`ModelHelpers.parseDouble/parseBool/parseInt/parseStringList/parsePhotos`) to tolerate messy Firestore data — follow this when adding fields. Common base: `models/place_base.dart`; categories: `models/place_enums.dart`. `lib/repositories/places_repository.dart` defines a separate generic `PlaceItem` (with a `meta` map) used by admin content forms.

### Firestore collections

`users` (central: `role`, `isAdmin`, `isVerified`, `phone`), `sites`, `restaurants`, `hotels`, `events`, `business`, `shopping`, `reels`, `ads`, `drafts`, `favorites`, `likes`, `comments`, `notifications`, `fcmTokens`.

⚠️ Inconsistency: Cloud Functions triggers (functions/index.js) listen on `entreprises` and `shoppings`, while client code uses `business`/`shopping`. Verify collection names when touching those categories.

### Cloud Functions (functions/index.js, Node gen-2)

`onNewSite/Restaurant/Hotel/Event/Entreprise/Shopping` (FCM push on new content), `sendCustomNotification` (onCall), `cleanupOldNotifications` (daily schedule), `deleteMyAccount` (onCall).

### Admin panel (lib/views/admin/)

`admin_screen.dart` shell + `contents/` (place CRUD + drafts workflow), `ads/`, `reels/`.

### i18n & theming

Custom lightweight i18n in `lib/localization/app_localizations.dart` — a nested fr/en string map via `AppLocalizations.translate(...)`, NOT ARB/gen-l10n. Default locale `fr_FR`. Themes: Material 3, primary green `#05814C`, secondary gold; defined in `main.dart` (`_buildLightTheme`/`_buildDarkTheme`) and `lib/themes/app_theme.dart`. Custom font: Satoshi.

### Services pattern

Static-method or plain classes hitting Firestore/Storage directly: `places_service.dart`, `image_service.dart` (compress to JPEG max 1920px/q85 then upload to Storage), `ad_service.dart`, `content_service.dart`, `notification_service.dart`, `new_place_watcher_service.dart` (singleton started at login), `location_service.dart`, `geocoding_service.dart` (OpenStreetMap Nominatim via http).

## Repo oddities

- `import-final/` and `scripts/apify_import/` — one-off Node.js Firestore data-import tools, not app code.
- `yes/` — second Cloud Functions codebase (see deploy warning).
- `firestore/notification_service.dart` — stray file outside lib/.
- `cors.json` — permissive Storage CORS config, applied via gsutil.
- `.agents/skills/` and `.windsurf/skills/` — vendored Firebase agent skills (reference material, not project rules).
- README.md (French) is the most complete doc on intent/architecture, but trust code over README where they disagree (e.g. package name).
