import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

/// Provider exposant l’état d’authentification courant.
/// La valeur sera `null` si aucun utilisateur n’est connecté.
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
      Firebase.app();
    }
  } catch (e) {
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

/// Splash Flutter plein écran (relais après le splash natif).
/// IMPORTANT : ajouter l’asset dans pubspec.yaml
/// flutter:
///   assets:
///     - assets/images/splash_bleu.jpg
class FullscreenSplash extends StatelessWidget {
  const FullscreenSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox.expand(
        child: Image(
          image: AssetImage('assets/images/splash_bleu.jpg'),
          fit: BoxFit.cover, // prend tout l’écran (peut couper si ratio différent)
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

class KinExperienceApp extends ConsumerWidget {
  const KinExperienceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);

    Widget determineHome() {
      return authAsync.when(
        data: (user) {
          return user == null ? const AuthScreen() : const HomeScreen();
        },

        // ✅ Ici on affiche ton image plein écran pendant le chargement
        loading: () => const FullscreenSplash(),

        error: (error, stack) => Scaffold(
          body: Center(
            child: Text('Erreur : ${error.toString()}'),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kin-Experience',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
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
      home: determineHome(),
    );
  }
}
