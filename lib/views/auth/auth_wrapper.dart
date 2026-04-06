// lib/views/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_screen.dart';
import '../home_screen.dart';
import '../admin/admin_screen.dart';
import 'otp_verification_screen.dart';
import '../../services/notification_service.dart';

/// Provider pour l'état d'authentification
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Provider pour l'utilisateur courant
final currentUserProvider = Provider<User?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  debugPrint('🔑 Current user: ${user?.email}');
  return user;
});

/// Vérifie si l'utilisateur est connecté
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// Liste d'emails admin
const Set<String> _adminEmails = {
  'admin@mail.com',
  'tys@mail.com',
  'user@mail.com',
};

/// Vérifie si l'utilisateur est admin
Future<bool> _isAdminUser(User user) async {
  final email = (user.email ?? '').trim().toLowerCase();

  // Option 1 : whitelist email
  if (_adminEmails.map((e) => e.toLowerCase()).contains(email)) {
    debugPrint('✅ Admin by email whitelist: $email');
    return true;
  }

  // Option 2 : Firestore users/{uid}
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) return false;

    final data = doc.data() ?? {};
    final role = (data['role'] ?? '').toString().toLowerCase();
    final isAdmin = data['isAdmin'] == true;

    if (isAdmin || role == 'admin') return true;
    return false;
  } catch (e) {
    debugPrint('❌ Error checking Firestore: $e');
    return false;
  }
}

/// ✅ NOUVEAU : Vérifie si l'utilisateur a validé son OTP
Future<bool> _isUserVerified(User user) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!doc.exists) return false;

    final data = doc.data() ?? {};
    return data['isVerified'] == true;
  } catch (e) {
    debugPrint('❌ Error checking verification: $e');
    return false;
  }
}

/// ✅ NOUVEAU : Récupère le téléphone de l'utilisateur depuis Firestore
Future<String> _getUserPhone(User user) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!doc.exists) return '';
    return (doc.data()?['phone'] ?? '').toString();
  } catch (_) {
    return '';
  }
}

/// Provider pour vérifier si l'utilisateur est admin
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  final isAdmin = await _isAdminUser(user);
  debugPrint('🎯 isAdminProvider result: $isAdmin for ${user.email}');
  return isAdmin;
});

/// ✅ NOUVEAU : Provider pour vérifier si l'utilisateur est vérifié (OTP)
final isVerifiedProvider = FutureProvider<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  return await _isUserVerified(user);
});

// ═══════════════════════════════════════════════════════════════════════════
// AUTH WRAPPER
// ═══════════════════════════════════════════════════════════════════════════

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    try {
      await NotificationService().initialize();
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          debugPrint('📱 AuthWrapper: No user → AuthScreen');
          return const AuthScreen();
        }

        debugPrint('📱 AuthWrapper: User logged in: ${user.email}');

        // ✅ Vérifier si le compte est vérifié (OTP)
        final isVerifiedAsync = ref.watch(isVerifiedProvider);

        return isVerifiedAsync.when(
          data: (isVerified) {
            if (!isVerified) {
              // ✅ Pas encore vérifié → écran de vérification OTP
              debugPrint('📱 AuthWrapper: Not verified → OtpVerificationScreen');
              return FutureBuilder<String>(
                future: _getUserPhone(user),
                builder: (context, phoneSnapshot) {
                  if (phoneSnapshot.connectionState == ConnectionState.waiting) {
                    return const _SplashScreen();
                  }
                  return OtpVerificationScreen(
                    email: user.email ?? '',
                    phone: phoneSnapshot.data ?? '',
                  );
                },
              );
            }

            // ✅ Vérifié → vérifier admin
            final isAdminAsync = ref.watch(isAdminProvider);

            return isAdminAsync.when(
              data: (isAdmin) {
                debugPrint(
                    '📱 AuthWrapper: isAdmin=$isAdmin → ${isAdmin ? "AdminScreen" : "HomeScreen"}');

                if (isAdmin) {
                  return const AdminScreen();
                } else {
                  return const HomeScreen();
                }
              },
              loading: () => const _SplashScreen(),
              error: (e, st) {
                debugPrint('❌ AuthWrapper: Error checking admin: $e');
                return const HomeScreen();
              },
            );
          },
          loading: () {
            debugPrint('📱 AuthWrapper: Checking verification...');
            return const _SplashScreen();
          },
          error: (e, st) {
            debugPrint('❌ AuthWrapper: Error checking verification: $e');
            // En cas d'erreur, laisser passer vers le home
            return const HomeScreen();
          },
        );
      },
      loading: () {
        debugPrint('📱 AuthWrapper: Loading auth state...');
        return const _SplashScreen();
      },
      error: (error, stack) {
        debugPrint('❌ AuthWrapper: Auth error: $error');
        return _ErrorScreen(error: error.toString());
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SPLASH SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo/kin_city.png',
              height: 120,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.location_city,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement...',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white,
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  FirebaseAuth.instance.signOut();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AUTH EXTENSIONS & MIXINS
// ═══════════════════════════════════════════════════════════════════════════

extension AuthCheck on BuildContext {
  void requireAuth() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.of(this).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
            (_) => false,
      );
    }
  }
}

mixin RequiresAuthMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
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
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
            (_) => false,
      );
    }
  }
}

class AuthGuard extends ConsumerWidget {
  final Widget child;
  final Widget? loadingWidget;
  final Widget? unauthorizedWidget;

  const AuthGuard({
    super.key,
    required this.child,
    this.loadingWidget,
    this.unauthorizedWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return unauthorizedWidget ?? const AuthScreen();
        }
        return child;
      },
      loading: () => loadingWidget ?? const Center(child: CircularProgressIndicator()),
      error: (_, __) => unauthorizedWidget ?? const AuthScreen(),
    );
  }
}