import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../views/auth/dual_auth_screen.dart';
import '../views/home_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// AUTH STATE PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Provider qui écoute les changements d'état d'authentification
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Provider pour l'utilisateur actuel (synchrone)
final currentUserProvider = Provider<User?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    print('👤 Current user: ${user.email ?? user.phoneNumber}');
  }
  return user;
});

/// Provider pour vérifier si l'utilisateur est connecté
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (user) => user != null,
    orElse: () => false,
  );
});

/// Provider pour obtenir les données utilisateur depuis Firestore
final userDataProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return doc.exists ? doc.data() : null;
  } catch (e) {
    print('❌ Error getting user data: $e');
    return null;
  }
});

/// Provider pour vérifier si l'utilisateur est admin
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  // 1. Vérification par email (liste blanche)
  const adminEmails = {
    'admin@mail.com',
    'tys@mail.com',
  };

  final email = (user.email ?? '').toLowerCase().trim();
  if (adminEmails.contains(email)) {
    print('✅ Admin by email whitelist: $email');
    return true;
  }

  // 2. Vérification par numéro de téléphone (liste blanche)
  const adminPhones = {
    '+243123456789',  // Exemple
  };

  final phone = user.phoneNumber ?? '';
  if (adminPhones.contains(phone)) {
    print('✅ Admin by phone whitelist: $phone');
    return true;
  }

  // 3. Vérification Firestore
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data() ?? {};
      final isAdmin = data['isAdmin'] == true;
      final role = (data['role'] ?? '').toString().toLowerCase();

      if (isAdmin || role == 'admin') {
        print('✅ Admin by Firestore: isAdmin=$isAdmin, role=$role');
        return true;
      }
    }
  } catch (e) {
    print('❌ Error checking admin in Firestore: $e');
  }

  return false;
});

/// Provider pour obtenir la méthode d'authentification de l'utilisateur
final authMethodProvider = Provider<String>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return 'none';

  if (user.email != null && user.email!.isNotEmpty) {
    return 'email';
  } else if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
    return 'phone';
  }

  return 'unknown';
});

/// Provider pour vérifier si l'utilisateur a lié les deux méthodes
final hasLinkedAccountsProvider = FutureProvider<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  // Recharger les providers pour avoir les infos à jour
  await user.reload();
  final currentUser = FirebaseAuth.instance.currentUser;

  final hasEmail = currentUser?.email != null && currentUser!.email!.isNotEmpty;
  final hasPhone = currentUser?.phoneNumber != null && currentUser!.phoneNumber!.isNotEmpty;

  return hasEmail && hasPhone;
});

// ═══════════════════════════════════════════════════════════════════════════
// AUTH SERVICE CLASS
// ═══════════════════════════════════════════════════════════════════════════

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Lier un email à un compte téléphone existant
  Future<void> linkEmailToAccount({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Aucun utilisateur connecté');

    if (user.email != null) {
      throw Exception('Un email est déjà lié à ce compte');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await user.linkWithCredential(credential);

      // Mettre à jour Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'email': email,
        'authMethod': 'email+phone',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Email lié au compte: $email');
    } catch (e) {
      print('❌ Erreur liaison email: $e');
      rethrow;
    }
  }

  /// Lier un téléphone à un compte email existant
  Future<void> linkPhoneToAccount({
    required String verificationId,
    required String smsCode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Aucun utilisateur connecté');

    if (user.phoneNumber != null) {
      throw Exception('Un téléphone est déjà lié à ce compte');
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      await user.linkWithCredential(credential);

      // Mettre à jour Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'phoneNumber': user.phoneNumber,
        'authMethod': 'email+phone',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Téléphone lié au compte: ${user.phoneNumber}');
    } catch (e) {
      print('❌ Erreur liaison téléphone: $e');
      rethrow;
    }
  }

  /// Délier l'email du compte
  Future<void> unlinkEmail() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Aucun utilisateur connecté');

    if (user.phoneNumber == null) {
      throw Exception('Vous devez avoir au moins une méthode d\'authentification');
    }

    try {
      await user.unlink(EmailAuthProvider.PROVIDER_ID);

      await _firestore.collection('users').doc(user.uid).update({
        'email': FieldValue.delete(),
        'authMethod': 'phone',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Email délié du compte');
    } catch (e) {
      print('❌ Erreur déliaison email: $e');
      rethrow;
    }
  }

  /// Délier le téléphone du compte
  Future<void> unlinkPhone() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Aucun utilisateur connecté');

    if (user.email == null) {
      throw Exception('Vous devez avoir au moins une méthode d\'authentification');
    }

    try {
      await user.unlink(PhoneAuthProvider.PROVIDER_ID);

      await _firestore.collection('users').doc(user.uid).update({
        'phoneNumber': FieldValue.delete(),
        'authMethod': 'email',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Téléphone délié du compte');
    } catch (e) {
      print('❌ Erreur déliaison téléphone: $e');
      rethrow;
    }
  }

  /// Obtenir les informations du compte
  Future<AccountInfo> getAccountInfo() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Aucun utilisateur connecté');

    await user.reload();
    final currentUser = _auth.currentUser;

    return AccountInfo(
      uid: currentUser!.uid,
      email: currentUser.email,
      phoneNumber: currentUser.phoneNumber,
      displayName: currentUser.displayName,
      photoURL: currentUser.photoURL,
      hasEmail: currentUser.email != null,
      hasPhone: currentUser.phoneNumber != null,
    );
  }
}

/// Provider pour AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// ═══════════════════════════════════════════════════════════════════════════
// ACCOUNT INFO MODEL
// ═══════════════════════════════════════════════════════════════════════════

class AccountInfo {
  final String uid;
  final String? email;
  final String? phoneNumber;
  final String? displayName;
  final String? photoURL;
  final bool hasEmail;
  final bool hasPhone;

  AccountInfo({
    required this.uid,
    this.email,
    this.phoneNumber,
    this.displayName,
    this.photoURL,
    required this.hasEmail,
    required this.hasPhone,
  });

  bool get hasLinkedAccounts => hasEmail && hasPhone;

  String get primaryAuthMethod {
    if (hasEmail && hasPhone) return 'email+phone';
    if (hasEmail) return 'email';
    if (hasPhone) return 'phone';
    return 'none';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AUTH WRAPPER WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const DualAuthScreen();
        }
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
// HELPER POUR LA DÉCONNEXION
// ═══════════════════════════════════════════════════════════════════════════

Future<void> signOutAndRedirect(BuildContext context) async {
  await FirebaseAuth.instance.signOut();

  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DualAuthScreen()),
          (_) => false,
    );
  }
}