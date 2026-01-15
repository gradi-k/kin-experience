import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../localization/app_localizations.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ✅ Nouveaux champs profil
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

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
    if (email.isEmpty) return 'Veuillez renseigner l’email.';
    if (pass.length < 6) return 'Mot de passe trop court (min 6).';
    if (pass != confirm) return 'Les mots de passe ne correspondent pas.';
    return null;
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
        await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
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
        setState(() => _errorMessage = 'Création de compte échouée (user null).');
        return;
      }

      // ✅ Force token refresh (évite certains cas où Firestore voit request.auth null)
      await user.getIdToken(true);

      // ✅ Écrire le profil dans Firestore
      try {
        await db.collection('users').doc(user.uid).set({
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': user.email ?? _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } on FirebaseException catch (e) {
        // Important: ici ce n'est pas Auth, c'est Firestore (souvent rules / appcheck)
        setState(() {
          _errorMessage =
          'Firestore error (${e.code}) : ${e.message ?? e.toString()}';
        });
        return;
      }

      // ✅ Optionnel: displayName
      final displayName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      await user.updateDisplayName(displayName);
      await user.reload();

    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = 'Auth error (${e.code}) : ${e.message ?? e.toString()}';
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  InputDecoration _decoration(BuildContext context, String label) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: theme.brightness == Brightness.light
          ? Colors.grey.shade100
          : Colors.grey.shade800,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.light
          ? Colors.white
          : theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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

                // ✅ LOGO AU DESSUS DU FORMULAIRE
                SizedBox(
                  height: 90,
                  child: Image.asset(
                    'assets/images/logo/logo.png', // ✅ change le chemin si besoin
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.location_city,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 14),


                _isLogin
                    ? RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.headlineSmall?.color, // garde la couleur du thème
                    ),
                    children: [
                      const TextSpan(
                        text: 'Bienvenue\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'Connectez-vous pour découvrir Kinshasa',
                        style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 18),
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

                // ✅ Champs supplémentaires en mode inscription
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

                // Email
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _decoration(context, loc.translate('email')),
                ),
                const SizedBox(height: 16),

                // Password
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _decoration(context, loc.translate('password')),
                ),

                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: _decoration(
                      context,
                      loc.translate('confirm_password'),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

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
                      _isLogin
                          ? loc.translate('sign_in')
                          : loc.translate('sign_up'),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

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
                        _isLogin
                            ? loc.translate('sign_up')
                            : loc.translate('sign_in'),
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
