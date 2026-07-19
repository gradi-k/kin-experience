import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Source unique de l'état d'authentification.
///
/// Trois fichiers définissaient chacun leur copie de ces providers
/// (auth_controller, dual_auth_controller, views/auth/auth_wrapper) et
/// main.dart avait encore sa propre logique en parallèle. Tout passe désormais
/// par ici.
///
/// L'authentification est **optionnelle** : un visiteur non connecté peut
/// naviguer, chercher et consulter. Seules les actions liées à un compte
/// (favoris, avis, likes, profil) exigent une connexion — voir `requireAuth`
/// dans views/auth/auth_guard.dart.

// ═══════════════════════════════════════════════════════════════════════════
// ÉTAT D'AUTHENTIFICATION
// ═══════════════════════════════════════════════════════════════════════════

/// Utilisateur courant, en temps réel. `null` = visiteur.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Utilisateur courant, en lecture synchrone.
///
/// Dérivé de [authStateProvider] et non de `FirebaseAuth.instance.currentUser` :
/// les anciennes versions lisaient `currentUser` une fois pour toutes et ne se
/// reconstruisaient jamais, laissant l'UI sur l'état d'avant la connexion.
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

/// `true` si un compte est connecté.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

// ═══════════════════════════════════════════════════════════════════════════
// PROFIL & RÔLES
// ═══════════════════════════════════════════════════════════════════════════

/// Emails admin en dur, en secours si le document `users/{uid}` n'est pas
/// encore renseigné.
///
/// Cette liste était dupliquée (main.dart en avait une, auth_controller une
/// autre, plus courte). Source unique ici.
const Set<String> kAdminEmails = {
  'admin@mail.com',
  'tys@mail.com',
  'user@mail.com',
};

/// Document `users/{uid}`, en temps réel. `null` pour un visiteur.
final userDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data());
});

/// `true` si l'utilisateur est admin (liste blanche, `role == 'admin'`, ou
/// `isAdmin == true`).
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final email = (user.email ?? '').trim().toLowerCase();
  if (kAdminEmails.map((e) => e.toLowerCase()).contains(email)) return true;

  final data = ref.watch(userDocProvider).value;
  if (data == null) return false;

  return data['isAdmin'] == true ||
      (data['role'] ?? '').toString().toLowerCase() == 'admin';
});

/// `true` si le compte a passé la vérification OTP.
final isVerifiedProvider = Provider<bool>((ref) {
  final data = ref.watch(userDocProvider).value;
  return data?['isVerified'] == true;
});

/// Téléphone enregistré sur le profil, chaîne vide si absent.
final userPhoneProvider = Provider<String>((ref) {
  final data = ref.watch(userDocProvider).value;
  return (data?['phone'] ?? '').toString();
});

Future<void> signOut() => FirebaseAuth.instance.signOut();
