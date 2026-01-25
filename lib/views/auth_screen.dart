// lib/views/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../localization/app_localizations.dart';
import 'admin_screen.dart';
import 'home_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ✅ Champs profil (signup)
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  // ✅ Liste d'emails admin
  static const Set<String> adminEmails = {
    'admin@mail.com',
    'tys@mail.com',
    'user@mail.com',
  };

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateSignupInputs(AppLocalizations loc) {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (first.isEmpty) return 'Veuillez renseigner le prénom.';
    if (last.isEmpty) return 'Veuillez renseigner le nom.';
    if (phone.isEmpty) return 'Veuillez renseigner le numéro de téléphone.';
    if (phone.length < 8) return 'Numéro de téléphone invalide.';
    if (email.isEmpty) return "Veuillez renseigner l'email.";
    if (pass.length < 6) return 'Mot de passe trop court (min 6).';
    if (pass != confirm) return 'Les mots de passe ne correspondent pas.';
    return null;
  }

  /// ✅ Vérifie si l'utilisateur est admin
  Future<bool> _isAdminUser(User user) async {
    final email = (user.email ?? '').trim().toLowerCase();

    // Option 1 : whitelist email
    if (adminEmails.map((e) => e.toLowerCase()).contains(email)) return true;

    // Option 2 : Firestore users/{uid} : role == "admin" OU isAdmin == true
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      final data = doc.data() ?? {};
      final role = (data['role'] ?? '').toString().toLowerCase();
      final isAdmin = data['isAdmin'] == true;

      if (isAdmin) return true;
      if (role == 'admin') return true;

      return false;
    } catch (_) {
      return false;
    }
  }

  /// ✅ Vérifie si le compte utilisateur existe dans Firestore
  Future<bool> _userProfileExists(User user) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;

    try {
      if (_isLogin) {
        // ✅ LOGIN
        final cred = await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = cred.user;
        if (user == null) {
          setState(() => _errorMessage = 'Connexion échouée.');
          return;
        }

        // ✅ Force le rafraîchissement du token
        await user.getIdToken(true);

        // ✅ Vérifier si le profil existe dans Firestore
        final profileExists = await _userProfileExists(user);
        if (!profileExists) {
          // Compte n'existe pas dans Firestore → refuser l'accès
          await auth.signOut();
          setState(() {
            _errorMessage = 'Ce compte n\'est pas autorisé. Veuillez contacter l\'administrateur.';
          });
          return;
        }

        // ✅ Vérifier automatiquement si admin
        final isAdmin = await _isAdminUser(user);

        if (!mounted) return;

        if (isAdmin) {
          // ✅ Utilisateur admin → AdminScreen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AdminScreen()),
                (_) => false,
          );
        } else {
          // ✅ Utilisateur normal → HomeScreen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
                (_) => false,
          );
        }
        return;
      }

      // ✅ INSCRIPTION
      final loc = AppLocalizations.of(context)!;
      final err = _validateSignupInputs(loc);
      if (err != null) {
        setState(() => _errorMessage = err);
        return;
      }

      final userCredential = await auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user == null) {
        setState(() => _errorMessage = 'Création de compte échouée.');
        return;
      }

      // ✅ Force le rafraîchissement du token
      await user.getIdToken(true);

      // ✅ Crée un profil "user" par défaut (pas admin)
      try {
        await db.collection('users').doc(user.uid).set({
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': user.email ?? _emailController.text.trim(),
          'role': 'user',
          'isAdmin': false,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } on FirebaseException catch (e) {
        setState(() {
          _errorMessage = 'Erreur lors de la création du profil: ${e.message ?? e.toString()}';
        });
        return;
      }

      final displayName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      await user.updateDisplayName(displayName);
      await user.reload();

      // ✅ Après inscription, rediriger vers HomeScreen
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
            (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getAuthErrorMessage(e.code);
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ✅ Messages d'erreur en français
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Aucun compte trouvé avec cet email.';
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'email-already-in-use':
        return 'Cette adresse email est déjà utilisée.';
      case 'weak-password':
        return 'Le mot de passe est trop faible.';
      default:
        return 'Une erreur est survenue. Veuillez réessayer.';
    }
  }

  InputDecoration _decoration(BuildContext context, String hint) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.brightness == Brightness.light
          ? Colors.grey.shade100
          : Colors.grey.shade800,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
      theme.brightness == Brightness.light ? Colors.white : theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ✅ Bouton retour pour inscription
                if (!_isLogin)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: theme.colorScheme.primary,
                      onPressed: () {
                        setState(() {
                          _isLogin = true;
                          _errorMessage = null;
                        });
                      },
                    ),
                  ),

                const SizedBox(height: 10),

                // ✅ Logo
                SizedBox(
                  height: 90,
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

                const SizedBox(height: 14),

                // ✅ Titre
                _isLogin
                    ? RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.headlineSmall?.color,
                    ),
                    children: const [
                      TextSpan(
                        text: 'Bienvenue\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'Connectez-vous pour découvrir Kinshasa',
                        style: TextStyle(fontWeight: FontWeight.normal, fontSize: 18),
                      ),
                    ],
                  ),
                )
                    : Text(
                  loc.translate('signup_title'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 26),

                // ✅ Champs inscription
                if (!_isLogin) ...[
                  TextField(
                    controller: _firstNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _decoration(context, 'Prénom'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _lastNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _decoration(context, 'Nom'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
                    ],
                    decoration: _decoration(context, 'Téléphone'),
                  ),
                  const SizedBox(height: 16),
                ],

                // ✅ Email
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _decoration(context, loc.translate('email')),
                ),
                const SizedBox(height: 16),

                // ✅ Mot de passe
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _decoration(context, loc.translate('password')),
                ),

                // ✅ Confirmation mot de passe (inscription)
                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: _decoration(context, loc.translate('confirm_password')),
                  ),
                ],

                const SizedBox(height: 18),

                // ✅ Message d'erreur
                if (_errorMessage != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                // ✅ Bouton Se connecter / S'inscrire
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _authenticate,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      _isLogin ? loc.translate('sign_in') : loc.translate('sign_up'),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ✅ Toggle Login/Signup
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin
                          ? loc.translate('dont_have_account')
                          : loc.translate('already_have_account'),
                      style: theme.textTheme.bodySmall,
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _errorMessage = null;
                        });
                      },
                      child: Text(
                        _isLogin ? loc.translate('sign_up') : loc.translate('sign_in'),
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}