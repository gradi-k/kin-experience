// lib/main.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'controllers/auth_controller.dart';
import 'controllers/locale_controller.dart';
import 'controllers/theme_controller.dart';
import 'localization/app_localizations.dart';
import 'views/auth/otp_verification_screen.dart';
import 'views/home_screen.dart';
import 'views/admin/admin_screen.dart';
import 'views/onboarding_screen.dart';
import 'package:cityguide/services/new_place_watcher_service.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Firebase init (anti duplicate)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      Firebase.app();
    }
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      Firebase.app();
    } else {
      debugPrint('Firebase init error: $e');
    }
  }

  // ✅ Persistance Firestore (mode hors-ligne) — doit être configurée
  // avant la première utilisation de Firestore.
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firestore persistence error: $e');
  }

  // ✅ App Check
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
  } catch (e) {
    debugPrint('AppCheck activate error: $e');
  }

  // ✅ Services non critiques : initialisés en arrière-plan pour ne pas
  // bloquer l'affichage du premier écran.
  unawaited(_initDeferredServices());

  // ✅ Start NewPlaceWatcherService only when user is logged in
  bool watcherStarted = false;
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null && !watcherStarted) {
      watcherStarted = true;
      NewPlaceWatcherService().startWatching();
      debugPrint('✅ NewPlaceWatcherService started for user ${user.uid}');
    } else if (user == null) {
      watcherStarted = false;
      debugPrint('ℹ️ User signed out: watcher stopped/not running');
    }
  });

  // ✅ Status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: CityGuideApp()));
}

/// Initialisation des services non critiques, hors du chemin de démarrage.
Future<void> _initDeferredServices() async {
  try {
    await FirebaseAuth.instance.setLanguageCode('fr');
  } catch (e) {
    debugPrint('setLanguageCode error: $e');
  }

  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Notification service error: $e');
  }
}

class CityGuideApp extends ConsumerWidget {
  const CityGuideApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'City Guide Officiel',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      locale: locale,
      home: const AppEntryPoint(),
    );
  }

  ThemeData _buildLightTheme() {
    const primaryColor = Color(0xFF05814C);
    const secondaryColor = Color(0xFFE9AE27);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.grey.shade50,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white.withOpacity(0.95),
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey.shade600,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const primaryColor = Color(0xFF05814C);
    const secondaryColor = Color(0xFFFFAB40);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF05814C),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: const Color(0xFF1E1E1E),
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1E1E1E).withOpacity(0.95),
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey.shade500,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

/// Point d'entrée de l'app - Gère le flux:
/// Splash → Onboarding (1ère fois) → Auth → OTP Verification → Home/Admin
class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  bool _isLoading = true;
  bool _hasSeenOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    bool seen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(OnboardingScreen.kSeenOnboardingKey) ?? false;
    } catch (_) {
      // En cas d'erreur, on considère l'onboarding non vu.
    }

    if (!mounted) return;
    setState(() {
      _hasSeenOnboarding = seen;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SplashScreen();
    }

    if (!_hasSeenOnboarding) {
      return const OnboardingScreen();
    }

    return const AuthGate();
  }
}

/// AuthGate — aiguille vers le bon écran de démarrage.
///
/// ✅ L'authentification est **optionnelle** : un visiteur non connecté arrive
/// directement sur la home. Les actions liées à un compte (favoris, avis,
/// likes, profil) déclenchent la feuille de connexion au moment voulu, via
/// `requireAuth` (views/auth/auth_guard.dart).
///
/// Un utilisateur connecté mais non vérifié passe encore par l'OTP : la
/// vérification protège son compte, pas l'accès au contenu.
///
/// Les emails admin et la lecture de `users/{uid}` vivent désormais dans
/// controllers/auth_controller.dart — ils étaient dupliqués ici.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const SplashScreen(),
      // Une auth en échec ne doit pas bloquer l'app : le contenu est public.
      error: (e, _) {
        debugPrint('❌ AuthGate: $e → HomeScreen (visiteur)');
        return const HomeScreen();
      },
      data: (user) {
        if (user == null) {
          debugPrint('📱 AuthGate: visiteur → HomeScreen');
          return const HomeScreen();
        }

        // userDocProvider alimente isVerified et isAdmin en une seule
        // souscription à users/{uid}.
        final userDoc = ref.watch(userDocProvider);
        if (userDoc.isLoading) return const SplashScreen();

        if (!ref.watch(isVerifiedProvider)) {
          debugPrint('📱 AuthGate: non vérifié → OtpVerificationScreen');
          return OtpVerificationScreen(
            email: user.email ?? '',
            phone: ref.watch(userPhoneProvider),
          );
        }

        final isAdmin = ref.watch(isAdminProvider);
        debugPrint('📱 AuthGate: isAdmin=$isAdmin');
        return isAdmin ? const AdminScreen() : const HomeScreen();
      },
    );
  }
}

/// Écran de chargement (Splash Screen)
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF05814C);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/splash.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.location_city,
                    size: 100,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}