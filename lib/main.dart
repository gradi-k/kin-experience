import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'localization/app_localizations.dart';
import 'themes/app_theme.dart';
import 'views/home_screen.dart';
import 'views/auth_screen.dart';
import 'views/admin_screen.dart';
import 'firebase_options.dart';
import 'controllers/theme_controller.dart';

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

class _SplashScreenState extends State<SplashScreen> {
  static const String assetPath = 'assets/images/splash.png';
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
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
/// - Si user connecté => HomeScreen
/// - Sinon => AuthScreen

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  // ✅ Email whitelist (simple et fiable)
  static const Set<String> _adminEmails = {
    'admin@mail.com',
    // Ajoute d'autres emails si besoin
  };

  Future<bool> _isAdmin(User user) async {
    final email = user.email?.toLowerCase().trim();
    if (email != null && _adminEmails.contains(email)) return true;

    // ✅ Optionnel : si tu stockes le rôle dans Firestore (users/{uid})
    // Exemples:
    // { "role": "admin" } ou { "isAdmin": true }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();
      if (data == null) return false;

      if (data['isAdmin'] == true) return true;

      final role = (data['role'] ?? data['type'] ?? data['userType'])
          ?.toString()
          .toLowerCase()
          .trim();

      return role == 'admin';
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return const AuthScreen();

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
