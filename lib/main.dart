// lib/main.dart
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
import 'controllers/theme_controller.dart';
import 'localization/app_localizations.dart';
import 'views/auth_screen.dart';
import 'views/home_screen.dart';
import 'views/admin_screen.dart';
import 'views/onboarding_screen.dart';


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

  // ✅ Auth locale
  try {
    await FirebaseAuth.instance.setLanguageCode('fr');
  } catch (e) {
    debugPrint('setLanguageCode error: $e');
  }

  // Initialiser les notifications
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Notification service error: $e');
  }

  // Configurer la barre de statut
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: KinExperienceApp()));
}

class KinExperienceApp extends ConsumerWidget {
  const KinExperienceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Kin City Guide',
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
      locale: const Locale('fr', 'FR'),
      home: const AppEntryPoint(),
    );
  }

  ThemeData _buildLightTheme() {
    // ✅ CHANGÉ : Couleur VERTE au lieu de bleue
    const primaryColor = Color(0xFF05814C);  // ✅ VERT (Kinshasa green)
    const secondaryColor = Color(0xFFE9AE27);  // ✅ JAUNE/OR

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
    // ✅ CHANGÉ : Couleur VERTE pour dark theme aussi
    const primaryColor = Color(0xFF05814C);  // ✅ VERT
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
          foregroundColor: Colors.white,  // ✅ Changé en blanc pour dark theme
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
/// Splash → Onboarding (1ère fois) → Auth → Home/Admin
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
    final start = DateTime.now();

    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(OnboardingScreen.kSeenOnboardingKey) ?? false;

      // ✅ garantir 3 secondes d’affichage splash
      final elapsed = DateTime.now().difference(start);
      final remaining = const Duration(seconds: 3) - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }

      if (!mounted) return;
      setState(() {
        _hasSeenOnboarding = seen;
        _isLoading = false;
      });
    } catch (e) {
      // ✅ garantir 3 secondes même en cas d'erreur
      final elapsed = DateTime.now().difference(start);
      final remaining = const Duration(seconds: 3) - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }

      if (!mounted) return;
      setState(() {
        _hasSeenOnboarding = false;
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {

    // Afficher le splash screen pendant le chargement
    if (_isLoading) {

      return const SplashScreen();
    }

    // Si l'onboarding n'a pas été vu, l'afficher
    if (!_hasSeenOnboarding) {
      return const OnboardingScreen();
    }

    // Sinon, afficher le AuthGate
    return const AuthGate();
  }
}

// ✅ Liste d'emails admin
const Set<String> _adminEmails = {
  'admin@mail.com',
  'tys@mail.com',
  'user@mail.com',
};

/// ✅ Vérifie si l'utilisateur est admin
Future<bool> _isAdminUser(User user) async {
  final email = (user.email ?? '').trim().toLowerCase();

  print('🔍 Checking admin for: $email');

  // Option 1 : whitelist email
  if (_adminEmails.map((e) => e.toLowerCase()).contains(email)) {
    print('✅ Admin by email whitelist: $email');
    return true;
  }

  // Option 2 : Firestore users/{uid}
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      print('❌ User doc does not exist in Firestore');
      return false;
    }

    final data = doc.data() ?? {};
    final role = (data['role'] ?? '').toString().toLowerCase();
    final isAdmin = data['isAdmin'] == true;

    print('📋 Firestore data: role=$role, isAdmin=$isAdmin');

    if (isAdmin) {
      print('✅ Admin by isAdmin field');
      return true;
    }
    if (role == 'admin') {
      print('✅ Admin by role field');
      return true;
    }

    print('❌ Not admin');
    return false;
  } catch (e) {
    print('❌ Error checking Firestore: $e');
    return false;
  }
}

/// AuthGate - Gère l'authentification
/// ✅ MODIFIÉ : Vérifie maintenant si l'utilisateur est admin
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Afficher un écran de chargement pendant la vérification
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // Si l'utilisateur n'est pas connecté, afficher AuthScreen
        if (!snapshot.hasData || snapshot.data == null) {
          print('📱 AuthGate: No user → AuthScreen');
          return const AuthScreen();
        }

        // ✅ NOUVEAU : Vérifier si admin
        final user = snapshot.data!;
        print('📱 AuthGate: User logged in: ${user.email}');

        return FutureBuilder<bool>(
          future: _isAdminUser(user),
          builder: (context, adminSnapshot) {
            // Afficher un écran de chargement pendant la vérification admin
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              print('📱 AuthGate: Checking admin status...');
              return const SplashScreen();
            }

            final isAdmin = adminSnapshot.data ?? false;
            print('📱 AuthGate: isAdmin=$isAdmin → ${isAdmin ? "AdminScreen" : "HomeScreen"}');

            // Rediriger selon le rôle
            if (isAdmin) {
              return const AdminScreen();
            } else {
              return const HomeScreen();
            }
          },
        );
      },
    );
  }
}

/// Écran de chargement (Splash Screen)
/// ✅ MODIFIÉ : Utilise maintenant la couleur VERTE
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ CHANGÉ : Fond VERT au lieu de bleu
    const backgroundColor = Color(0xFF05814C);  // ✅ VERT direct (pas via theme)

    return Scaffold(
      backgroundColor: backgroundColor,  // ✅ Vert hardcodé pour éviter le bleu
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

            // const SizedBox(height: 32),
            // const CircularProgressIndicator(
            //   color: Colors.white,
            //   strokeWidth: 2,
            // ),
            // const SizedBox(height: 16),
            // const Text(
            //   'Chargement...',
            //   style: TextStyle(
            //     color: Colors.white,
            //     fontSize: 16,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}