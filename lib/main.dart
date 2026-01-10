import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// Importation de flutter_riverpod à la place de hooks_riverpod.  Cela
// fournit ProviderScope, ConsumerWidget et les providers nécessaires
// sans utiliser les hooks, ce qui simplifie la configuration et
// évite les erreurs de compilation.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'localization/app_localizations.dart';
import 'themes/app_theme.dart';
import 'views/home_screen.dart';
import 'views/auth_screen.dart';
import 'firebase_options.dart';
import 'controllers/theme_controller.dart';

/// Provider exposant l’état d’authentification courant.  La valeur
/// sera `null` si aucun utilisateur n’est connecté.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔐 INITIALISATION BLINDÉE DE FIREBASE
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      // Si elle existe déjà, on récupère l'instance par défaut
      Firebase.app();
    }
  } catch (e) {
    // Si une erreur de duplication survient quand même, on la capture silencieusement
    debugPrint('Firebase déjà initialisé : $e');
  }

  // 🌍 Langue Firebase Auth en français
  await FirebaseAuth.instance.setLanguageCode('fr');

  runApp(
    const ProviderScope(
      child: KinExperienceApp(),
    ),
  );
}


class KinExperienceApp extends ConsumerWidget {
  const KinExperienceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observe l’état d’authentification afin de déterminer l’écran
    // initial.  Le provider renvoie `AsyncValue<User?>` qui reflète
    // l’état de chargement (pending), l’utilisateur courant ou une erreur.
    final authAsync = ref.watch(authStateProvider);

    // Observe le thème actuel (clair/sombre).
    final themeMode = ref.watch(themeModeProvider);

    // Détermine l’écran à afficher en fonction de l’état de
    // l’authentification.  Pendant le chargement, on affiche un
    // indicateur de progression.  En cas d’erreur, un message
    // d’erreur est affiché.  Si l’utilisateur est connecté, on
    // affiche HomeScreen ; sinon, AuthScreen.
    Widget determineHome() {
      return authAsync.when(
        data: (user) {
          return user == null ? const AuthScreen() : const HomeScreen();
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Scaffold(
          body: Center(
            child: Text('Erreur : \${error.toString()}'),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kin‑Experience',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Utilise le thème choisi via le [ThemeModeNotifier].
      themeMode: themeMode,
      // Langue par défaut fixée au français.  L’utilisateur pourra
      // changer la langue ultérieurement dans les paramètres si besoin.
      locale: const Locale('fr'),
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) return supportedLocales.first;
        for (final supported in supportedLocales) {
          if (supported.languageCode == locale.languageCode) {
            return supported;
          }
        }
        return supportedLocales.first;
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Affiche l’écran déterminé par l’état d’authentification.
      home: determineHome(),
    );
  }
}