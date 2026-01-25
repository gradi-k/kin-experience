// lib/views/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_screen.dart';
import 'home_screen.dart';
import 'admin_screen.dart';
import '../services/notification_service.dart';

/// Provider pour l'état d'authentification
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Provider pour l'utilisateur courant
final currentUserProvider = Provider<User?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  print('🔐 Current user: ${user?.email}');
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

/// Provider pour vérifier si l'utilisateur est admin
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('❌ No user logged in');
    return false;
  }

  final isAdmin = await _isAdminUser(user);
  print('🎯 isAdminProvider result: $isAdmin for ${user.email}');
  return isAdmin;
});

/// AuthWrapper - Gère la navigation en fonction de l'état d'authentification
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
          print('📱 AuthWrapper: No user → AuthScreen');
          return const AuthScreen();
        } else {
          print('📱 AuthWrapper: User logged in: ${user.email}');

          // ✅ Vérifier si admin
          final isAdminAsync = ref.watch(isAdminProvider);

          return isAdminAsync.when(
            data: (isAdmin) {
              print('📱 AuthWrapper: isAdmin=$isAdmin → ${isAdmin ? "AdminScreen" : "HomeScreen"}');

              if (isAdmin) {
                return const AdminScreen();
              } else {
                return const HomeScreen();
              }
            },
            loading: () {
              print('📱 AuthWrapper: Loading admin status...');
              return const _SplashScreen();
            },
            error: (e, st) {
              print('❌ AuthWrapper: Error checking admin: $e');
              return const HomeScreen();
            },
          );
        }
      },
      loading: () {
        print('📱 AuthWrapper: Loading auth state...');
        return const _SplashScreen();
      },
      error: (error, stack) {
        print('❌ AuthWrapper: Auth error: $error');
        return _ErrorScreen(error: error.toString());
      },
    );
  }
}

/// Écran de chargement
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

/// Écran d'erreur
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

/// Extension pour vérifier l'authentification
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

/// Mixin pour les widgets qui nécessitent l'authentification
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

/// Widget wrapper qui vérifie l'authentification
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