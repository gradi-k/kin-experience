import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../views/auth/auth_screen.dart';
import '../views/home_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// AUTH STATE PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider qui écoute les changements d'état d'authentification
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Provider pour l'utilisateur actuel (synchrone)
final currentUserProvider = Provider<User?>((ref) {
  return FirebaseAuth.instance.currentUser;
});

/// Provider pour vérifier si l'utilisateur est connecté
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (user) => user != null,
    orElse: () => false,
  );
});

/// Provider pour vérifier si l'utilisateur est admin
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  // Vérification par email (liste blanche)
  const adminEmails = {
    'admin@mail.com',
    'tys@mail.com',
  };

  final email = (user.email ?? '').toLowerCase().trim();
  if (adminEmails.contains(email)) return true;

  // Vérification Firestore (optionnel)
  // Décommentez si vous utilisez un champ isAdmin dans Firestore
  /*
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data() ?? {};
      return (data['isAdmin'] == true) || (data['role'] == 'admin');
    }
  } catch (_) {}
  */

  return false;
});

// ═══════════════════════════════════════════════════════════════════════════
// AUTH WRAPPER WIDGET
// ═══════════════════════════════════════════════════════════════════════════

/// Widget qui gère automatiquement la redirection selon l'état d'authentification.
///
/// Usage dans main.dart:
/// ```dart
/// MaterialApp(
///   home: const AuthWrapper(),
/// )
/// ```
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          // L'utilisateur n'est pas connecté -> Auth Screen
          return const AuthScreen();
        }
        // L'utilisateur est connecté -> Home Screen
        return const HomeScreen();
      },
      loading: () => const _LoadingScreen(),
      error: (error, stack) => _ErrorScreen(error: error.toString()),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LOADING SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo (optionnel)
            SizedBox(
              height: 100,
              child: Image.asset(
                'assets/images/logo/kin_city.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.location_city,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ERROR SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class _ErrorScreen extends StatelessWidget {
  final String error;

  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Une erreur est survenue',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Tenter de se reconnecter
                  FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AUTH GUARD MIXIN
// ═══════════════════════════════════════════════════════════════════════════

/// Mixin pour protéger les écrans nécessitant une authentification.
///
/// Usage:
/// ```dart
/// class MyProtectedScreen extends ConsumerStatefulWidget {
///   @override
///   ConsumerState<MyProtectedScreen> createState() => _MyProtectedScreenState();
/// }
///
/// class _MyProtectedScreenState extends ConsumerState<MyProtectedScreen>
///     with AuthGuardMixin {
///   @override
///   Widget build(BuildContext context) {
///     // L'utilisateur est redirigé automatiquement si non connecté
///     return Scaffold(...);
///   }
/// }
/// ```
mixin AuthGuardMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  @override
  void initState() {
    super.initState();
    _checkAuth();

    // Écouter les changements d'état d'auth
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null && mounted) {
        _redirectToAuth();
      }
    });
  }

  void _checkAuth() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _redirectToAuth();
      });
    }
  }

  void _redirectToAuth() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
          (_) => false,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER POUR LA DÉCONNEXION
// ═══════════════════════════════════════════════════════════════════════════

/// Déconnecte l'utilisateur et redirige vers l'écran d'auth
Future<void> signOutAndRedirect(BuildContext context) async {
  await FirebaseAuth.instance.signOut();

  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
          (_) => false,
    );
  }
}