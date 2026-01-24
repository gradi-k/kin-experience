import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:kin_experience/views/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';


import 'localization/app_localizations.dart';
import 'themes/app_theme.dart';
import 'views/home_screen.dart';
import 'views/auth_screen.dart';
import 'views/admin_screen.dart';
import 'firebase_options.dart';
import 'controllers/theme_controller.dart';

/// Clé globale pour accéder au NavigatorState depuis n'importe où
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

  runApp(const ProviderScope(child: KinExperienceApp()));
}

/// ✅ Splash plein écran (5s) puis AuthGate
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  static const _kSeenOnboardingKey = 'seen_onboarding';

  Future<bool> _hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSeenOnboardingKey) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasSeenOnboarding(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final seen = snap.data == true;
        return seen ? const AuthGate() : const OnboardingScreen();
      },
    );
  }
}
class _SplashScreenState extends State<SplashScreen> {
  static const String assetPath = 'assets/images/splash.png';
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer(const Duration(seconds: 7), () {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const BootGate()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox.expand(
        child: Image(
          image: AssetImage(assetPath),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

/// ✅ Widget qui écoute FirebaseAuth en continu
/// - Si user connecté => vérifie admin => HomeScreen ou AdminScreen
/// - Sinon => AuthScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _isAdmin(User user) async {
    // Admin is determined primarily by existence of /admins/{uid} (matches Firestore rules).
    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();
      if (adminDoc.exists) return true;
    } catch (_) {
      // Continue to fallback checks below.
    }

    // Fallback: check /users/{uid} flags.
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data();
      if (data != null) {
        final isAdmin = data['isAdmin'];
        final role = data['role'];
        if (isAdmin == true) return true;
        if (role is String && role.toLowerCase() == 'admin') return true;
      }
    } catch (_) {
      // ignore
    }

    // Last resort: email whitelist (useful during bootstrap).
    final email = (user.email ?? '').toLowerCase();
    return email == 'admin@mail.com';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ✅ Attente de l'état d'authentification
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // ✅ Pas d'utilisateur connecté → AuthScreen
        if (user == null) {
          return const AuthScreen();
        }

        // ✅ Utilisateur connecté → vérifier si admin
        return FutureBuilder<bool>(
          future: _isAdmin(user),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final isAdmin = roleSnap.data == true;
            return isAdmin ? const AdminScreen() : const HomeScreen();
          },
        );
      },
    );
  }
}

class KinExperienceApp extends ConsumerWidget {
  const KinExperienceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ Clé globale pour navigation
      debugShowCheckedModeBanner: false,
      title: 'Kin City Guide',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SplashScreen(),
    );
  }
}