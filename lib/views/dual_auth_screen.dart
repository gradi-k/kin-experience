import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DualAuthScreen extends StatefulWidget {
  const DualAuthScreen({super.key});

  @override
  State<DualAuthScreen> createState() => _DualAuthScreenState();
}

class _DualAuthScreenState extends State<DualAuthScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();

  // États
  bool _isLoading = false;
  bool _isLogin = true;
  AuthMethod _selectedMethod = AuthMethod.email;
  String? _verificationId;
  int? _resendToken;

  // UI
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTHENTIFICATION EMAIL
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _signInWithEmail() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showError('Veuillez remplir tous les champs');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print('✅ Connexion réussie: ${credential.user?.email}');

      // Navigation automatique via AuthWrapper
    } catch (e) {
      print('❌ Erreur connexion email: $e');
      _showError(_getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithEmail() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.trim().isEmpty) {
      _showError('Veuillez remplir tous les champs');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showError('Le mot de passe doit contenir au moins 6 caractères');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Créer le compte
      final credential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Mettre à jour le profil
      await credential.user?.updateDisplayName(_nameController.text.trim());

      // Créer le document utilisateur dans Firestore
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'authMethod': 'email',
        'createdAt': FieldValue.serverTimestamp(),
        'isAdmin': false,
      });

      print('✅ Inscription réussie: ${credential.user?.email}');

      _showSuccess('Compte créé avec succès !');

    } catch (e) {
      print('❌ Erreur inscription: $e');
      _showError(_getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTHENTIFICATION TÉLÉPHONE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _signInWithPhone() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showError('Veuillez entrer votre numéro de téléphone');
      return;
    }

    // Formater le numéro (ajouter +243 si nécessaire pour RDC)
    String formattedPhone = phone;
    if (!phone.startsWith('+')) {
      if (phone.startsWith('0')) {
        formattedPhone = '+243${phone.substring(1)}';
      } else {
        formattedPhone = '+243$phone';
      }
    }

    setState(() => _isLoading = true);

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),

        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-vérification (Android uniquement)
          print('🔄 Auto-vérification...');
          await _signInWithPhoneCredential(credential);
        },

        verificationFailed: (FirebaseAuthException e) {
          print('❌ Échec vérification: ${e.message}');
          if (mounted) {
            setState(() => _isLoading = false);
            _showError(_getErrorMessage(e));
          }
        },

        codeSent: (String verificationId, int? resendToken) {
          print('✅ Code envoyé au $formattedPhone');
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _isLoading = false;
            });
            _showOtpDialog();
          }
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          print('⏱️ Timeout auto-récupération');
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      print('❌ Erreur vérification téléphone: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Erreur lors de l\'envoi du code: $e');
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length != 6) {
      _showError('Veuillez entrer le code à 6 chiffres');
      return;
    }

    if (_verificationId == null) {
      _showError('Erreur de vérification. Veuillez réessayer.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      await _signInWithPhoneCredential(credential);

      Navigator.of(context).pop(); // Fermer le dialog OTP

    } catch (e) {
      print('❌ Erreur vérification OTP: $e');
      _showError('Code incorrect. Veuillez réessayer.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithPhoneCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      print('✅ Connexion téléphone réussie: ${user.phoneNumber}');

      // Créer ou mettre à jour le profil utilisateur
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // Nouveau utilisateur
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'phoneNumber': user.phoneNumber,
          'name': _nameController.text.trim().isEmpty
              ? 'Utilisateur ${user.phoneNumber}'
              : _nameController.text.trim(),
          'authMethod': 'phone',
          'createdAt': FieldValue.serverTimestamp(),
          'isAdmin': false,
        });
      }

    } catch (e) {
      print('❌ Erreur connexion credential: $e');
      rethrow;
    }
  }

  Future<void> _resendOtp() async {
    final phone = _phoneController.text.trim();
    String formattedPhone = phone;
    if (!phone.startsWith('+')) {
      if (phone.startsWith('0')) {
        formattedPhone = '+243${phone.substring(1)}';
      } else {
        formattedPhone = '+243$phone';
      }
    }

    setState(() => _isLoading = true);

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,

        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithPhoneCredential(credential);
        },

        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showError(_getErrorMessage(e));
          }
        },

        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _isLoading = false;
            });
            _showSuccess('Code renvoyé !');
          }
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Erreur lors du renvoi du code');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showOtpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Code de vérification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Un code à 6 chiffres a été envoyé au ${_phoneController.text}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                labelText: 'Code OTP',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _isLoading ? null : _resendOtp,
              icon: const Icon(Icons.refresh),
              label: const Text('Renvoyer le code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _verificationId = null;
                _otpController.clear();
              });
            },
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: _isLoading ? null : _verifyOtp,
            child: _isLoading
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Vérifier'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'Aucun compte trouvé avec cet email';
        case 'wrong-password':
          return 'Mot de passe incorrect';
        case 'email-already-in-use':
          return 'Cet email est déjà utilisé';
        case 'weak-password':
          return 'Le mot de passe est trop faible';
        case 'invalid-email':
          return 'Email invalide';
        case 'invalid-phone-number':
          return 'Numéro de téléphone invalide';
        case 'too-many-requests':
          return 'Trop de tentatives. Réessayez plus tard.';
        default:
          return error.message ?? 'Une erreur est survenue';
      }
    }
    return error.toString();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/logo/kin_city.png',
                  height: 100,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.location_city,
                    size: 80,
                    color: Color(0xFF0B7A4A),
                  ),
                ),
                const SizedBox(height: 32),

                // Titre
                Text(
                  _isLogin ? 'Connexion' : 'Inscription',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Connectez-vous à votre compte'
                      : 'Créez votre compte',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),

                // Choix de la méthode d'authentification
                SegmentedButton<AuthMethod>(
                  segments: const [
                    ButtonSegment(
                      value: AuthMethod.email,
                      label: Text('Email'),
                      icon: Icon(Icons.email_outlined),
                    ),
                    ButtonSegment(
                      value: AuthMethod.phone,
                      label: Text('Téléphone'),
                      icon: Icon(Icons.phone_outlined),
                    ),
                  ],
                  selected: {_selectedMethod},
                  onSelectionChanged: (Set<AuthMethod> newSelection) {
                    setState(() {
                      _selectedMethod = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 32),

                // Formulaire selon la méthode choisie
                if (_selectedMethod == AuthMethod.email)
                  _buildEmailForm()
                else
                  _buildPhoneForm(),

                const SizedBox(height: 24),

                // Bouton d'action principal
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0B7A4A),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                      _isLogin ? 'Se connecter' : 'S\'inscrire',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Toggle connexion/inscription
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin
                          ? 'Pas encore de compte ?'
                          : 'Vous avez déjà un compte ?',
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _clearFields();
                        });
                      },
                      child: Text(
                        _isLogin ? 'S\'inscrire' : 'Se connecter',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B7A4A),
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

  Widget _buildEmailForm() {
    return Column(
      children: [
        if (!_isLogin) ...[
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom complet',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneForm() {
    return Column(
      children: [
        if (!_isLogin) ...[
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom complet',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Numéro de téléphone',
            hintText: '+243 XXX XXX XXX ou 0XXX XXX XXX',
            prefixIcon: Icon(Icons.phone_outlined),
            border: OutlineInputBorder(),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Format: +243XXXXXXXXX ou 0XXXXXXXXX',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _handleSubmit() {
    if (_selectedMethod == AuthMethod.email) {
      if (_isLogin) {
        _signInWithEmail();
      } else {
        _signUpWithEmail();
      }
    } else {
      _signInWithPhone();
    }
  }

  void _clearFields() {
    _emailController.clear();
    _passwordController.clear();
    _phoneController.clear();
    _nameController.clear();
    _otpController.clear();
  }
}

enum AuthMethod { email, phone }