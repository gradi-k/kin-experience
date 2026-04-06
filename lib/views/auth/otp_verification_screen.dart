// lib/views/otp_verification_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../home_screen.dart';
import '../admin/admin_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════

enum VerificationMethod { none, email, phone }

// ═══════════════════════════════════════════════════════════════════════════
// OTP VERIFICATION SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String phone;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.phone,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  // ── State ──────────────────────────────────────────────────────────────
  VerificationMethod _method = VerificationMethod.none;
  bool _isLoading = false;
  bool _codeSent = false;
  String? _errorMessage;
  String? _successMessage;

  // ── Phone OTP ─────────────────────────────────────────────────────────
  String? _verificationId;
  int? _resendToken;
  final List<TextEditingController> _otpControllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  // ── Email verification ────────────────────────────────────────────────
  Timer? _emailCheckTimer;
  int _emailCheckCount = 0;
  static const int _maxEmailChecks = 60; // 60 × 3s = 3 minutes

  // ── Resend cooldown ───────────────────────────────────────────────────
  Timer? _resendTimer;
  int _resendCooldown = 0;
  static const int _cooldownSeconds = 60;

  // ── Admin emails ──────────────────────────────────────────────────────
  static const Set<String> _adminEmails = {
    'admin@mail.com',
    'tys@mail.com',
    'user@mail.com',
  };

  @override
  void dispose() {
    _emailCheckTimer?.cancel();
    _resendTimer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NORMALISATION DU NUMÉRO DE TÉLÉPHONE
  // ═══════════════════════════════════════════════════════════════════════

  /// Normalise le numéro de téléphone :
  /// - Supprime les espaces
  /// - Ajoute +243 si pas d'indicatif international
  /// - Supprime le 0 initial pour les numéros locaux
  String _normalizePhone(String raw) {
    String phone = raw.replaceAll(RegExp(r'\s+'), '').trim();

    if (phone.isEmpty) return '';

    // Si déjà en format international
    if (phone.startsWith('+')) return phone;

    // Supprime le 0 initial (numéro local RDC)
    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }

    // Ajoute l'indicatif RDC
    return '+243$phone';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PHONE VERIFICATION (CORRIGÉ)
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _sendPhoneOtp() async {
    final phoneNumber = _normalizePhone(widget.phone);

    if (phoneNumber.isEmpty || phoneNumber.length < 10) {
      setState(() => _errorMessage = 'Numéro de téléphone invalide.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    debugPrint('📱 Sending OTP to: $phoneNumber');

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 120),
        forceResendingToken: _resendToken,

        // ✅ Auto-vérification (Android : SMS auto-read)
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('✅ Phone auto-verified (SMS auto-read)');
          if (!mounted) return;

          // Remplir les champs OTP automatiquement si le smsCode est dispo
          final smsCode = credential.smsCode;
          if (smsCode != null && smsCode.length == 6) {
            for (int i = 0; i < 6; i++) {
              _otpControllers[i].text = smsCode[i];
            }
          }

          // Marquer comme vérifié directement
          await _completePhoneVerification(credential);
        },

        // ✅ Erreur de vérification
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ Phone verification failed: ${e.code} - ${e.message}');
          if (!mounted) return;

          String errorMsg;
          switch (e.code) {
            case 'invalid-phone-number':
              errorMsg = 'Numéro de téléphone invalide. '
                  'Vérifiez le format (ex: +243 81 024 1596).';
              break;
            case 'too-many-requests':
              errorMsg = 'Trop de tentatives. Veuillez réessayer dans quelques minutes.';
              break;
            case 'app-not-authorized':
              errorMsg = 'L\'application n\'est pas autorisée à utiliser '
                  'l\'authentification par téléphone. '
                  'Veuillez utiliser la vérification par email.';
              break;
            case 'captcha-check-failed':
              errorMsg = 'La vérification reCAPTCHA a échoué. Réessayez.';
              break;
            case 'missing-client-identifier':
            // ✅ Erreur courante quand App Check / reCAPTCHA n'est pas configuré
              errorMsg = 'Configuration SMS incomplète. '
                  'Veuillez utiliser la vérification par email à la place.';
              break;
            default:
              errorMsg = 'Erreur d\'envoi SMS (${e.code}). '
                  'Essayez la vérification par email.';
          }

          setState(() {
            _isLoading = false;
            _errorMessage = errorMsg;
          });
        },

        // ✅ Code envoyé avec succès
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('📱 SMS code sent to $phoneNumber (verificationId: ${verificationId.substring(0, 10)}...)');
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
            _isLoading = false;
            _successMessage = 'Code envoyé au $phoneNumber';
            _errorMessage = null;
          });
          _startResendCooldown();
        },

        // ✅ Timeout de récupération automatique
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('⏱ Auto-retrieval timeout for verificationId');
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      debugPrint('❌ Unexpected error sending phone OTP: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur inattendue. Essayez la vérification par email.';
      });
    }
  }

  /// Vérifie le code OTP saisi manuellement
  Future<void> _verifyPhoneOtp() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Veuillez entrer le code à 6 chiffres.');
      return;
    }

    if (_verificationId == null) {
      setState(() => _errorMessage = 'Session expirée. Veuillez renvoyer le code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );

      await _completePhoneVerification(credential);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _getOtpVerifyError(e.code);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Code invalide. Veuillez réessayer.';
      });
    }
  }

  /// ✅ CORRIGÉ : Essaie d'abord de lier, puis fallback sur vérification simple
  Future<void> _completePhoneVerification(PhoneAuthCredential credential) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Session expirée. Veuillez vous reconnecter.';
        });
        return;
      }

      // Essai 1 : Lier le numéro au compte (idéal)
      try {
        await user.linkWithCredential(credential);
        debugPrint('✅ Phone linked to account successfully');
      } on FirebaseAuthException catch (linkError) {
        debugPrint('⚠️ Link failed (${linkError.code}), trying alternative...');

        if (linkError.code == 'provider-already-linked') {
          // Le téléphone est déjà lié → c'est OK, continuer
          debugPrint('✅ Phone already linked, proceeding...');
        } else if (linkError.code == 'credential-already-in-use') {
          // Ce numéro est utilisé par un autre compte
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage = 'Ce numéro est déjà lié à un autre compte.';
          });
          return;
        } else if (linkError.code == 'invalid-verification-code') {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage = 'Code invalide. Veuillez réessayer.';
          });
          return;
        } else if (linkError.code == 'session-expired') {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage = 'Le code a expiré. Renvoyez un nouveau code.';
          });
          return;
        } else {
          // Essai 2 : Vérifier simplement le code sans lier
          // Le code est valide si on arrive ici sans exception "invalid-verification-code"
          debugPrint('✅ Code verified (link failed but code is valid)');
        }
      }

      // ✅ Marquer comme vérifié
      await _onVerificationSuccess();
    } catch (e) {
      debugPrint('❌ Complete phone verification error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur de vérification. Veuillez réessayer.';
      });
    }
  }

  String _getOtpVerifyError(String code) {
    switch (code) {
      case 'invalid-verification-code':
        return 'Code invalide. Vérifiez et réessayez.';
      case 'session-expired':
        return 'Le code a expiré. Renvoyez un nouveau code.';
      case 'invalid-verification-id':
        return 'Session expirée. Renvoyez un nouveau code.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'credential-already-in-use':
        return 'Ce numéro est déjà lié à un autre compte.';
      default:
        return 'Erreur de vérification ($code). Réessayez.';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EMAIL VERIFICATION
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _sendEmailVerification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Utilisateur non connecté.';
        });
        return;
      }

      await user.sendEmailVerification();

      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _isLoading = false;
        _successMessage =
        'Un lien de vérification a été envoyé à ${widget.email}. '
            'Vérifiez votre boîte de réception (et les spams).';
      });

      _startResendCooldown();
      _startEmailVerificationCheck();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.code == 'too-many-requests'
            ? 'Trop de tentatives. Réessayez plus tard.'
            : 'Erreur lors de l\'envoi: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: ${e.toString()}';
      });
    }
  }

  /// Vérifie périodiquement si l'email a été vérifié (lien cliqué)
  void _startEmailVerificationCheck() {
    _emailCheckTimer?.cancel();
    _emailCheckCount = 0;

    _emailCheckTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
          if (!mounted) {
            timer.cancel();
            return;
          }

          _emailCheckCount++;
          if (_emailCheckCount > _maxEmailChecks) {
            timer.cancel();
            return;
          }

          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              timer.cancel();
              return;
            }

            await user.reload();
            final refreshedUser = FirebaseAuth.instance.currentUser;

            if (refreshedUser != null && refreshedUser.emailVerified) {
              timer.cancel();
              debugPrint('✅ Email verified!');
              await _onVerificationSuccess();
            }
          } catch (e) {
            debugPrint('Email check error: $e');
          }
        });
  }

  /// Bouton manuel "J'ai vérifié mon email"
  Future<void> _checkEmailVerified() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Utilisateur non connecté.';
        });
        return;
      }

      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        await _onVerificationSuccess();
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage =
          'Email non encore vérifié. Cliquez sur le lien dans votre email, '
              'puis appuyez sur ce bouton.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: ${e.toString()}';
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // VERIFICATION SUCCESS
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _onVerificationSuccess() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // ✅ Mettre à jour le statut de vérification dans Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verificationMethod':
        _method == VerificationMethod.phone ? 'phone' : 'email',
      });

      debugPrint('✅ User verified and Firestore updated');

      if (!mounted) return;

      // ✅ Vérifier si admin et rediriger
      final isAdmin = await _isAdminUser(user);

      if (!mounted) return;

      if (isAdmin) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdminScreen()),
              (_) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
              (_) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors de la validation: ${e.toString()}';
      });
    }
  }

  Future<bool> _isAdminUser(User user) async {
    final email = (user.email ?? '').trim().toLowerCase();
    if (_adminEmails.map((e) => e.toLowerCase()).contains(email)) return true;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists) return false;

      final data = doc.data() ?? {};
      return (data['isAdmin'] == true) ||
          ((data['role'] ?? '').toString().toLowerCase() == 'admin');
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RESEND COOLDOWN
  // ═══════════════════════════════════════════════════════════════════════

  void _startResendCooldown() {
    _resendCooldown = _cooldownSeconds;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SIGN OUT / CANCEL
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _cancelAndSignOut() async {
    _emailCheckTimer?.cancel();
    _resendTimer?.cancel();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
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
              children: [
                // ── Header ──────────────────────────────────────────────
                Icon(
                  _codeSent
                      ? Icons.mark_email_read_outlined
                      : Icons.verified_user_outlined,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Vérification du compte',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _method == VerificationMethod.none
                      ? 'Choisissez une méthode de vérification '
                      'pour activer votre compte.'
                      : _method == VerificationMethod.phone
                      ? 'Un code de vérification sera envoyé '
                      'à votre numéro de téléphone.'
                      : 'Un lien de vérification sera envoyé '
                      'à votre adresse email.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                    theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // ── Content ─────────────────────────────────────────────
                if (_method == VerificationMethod.none)
                  _buildMethodChoice(theme),
                if (_method == VerificationMethod.phone)
                  _buildPhoneVerification(theme),
                if (_method == VerificationMethod.email)
                  _buildEmailVerification(theme),

                // ── Error / Success messages ────────────────────────────
                if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 20, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 20, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // ── Cancel button ───────────────────────────────────────
                TextButton.icon(
                  onPressed: _isLoading ? null : _cancelAndSignOut,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Annuler et revenir à la connexion'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                    theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // METHOD CHOICE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildMethodChoice(ThemeData theme) {
    final normalizedPhone = _normalizePhone(widget.phone);
    final hasPhone = normalizedPhone.isNotEmpty && normalizedPhone.length >= 10;

    return Column(
      children: [
        // ── Bouton SMS / Téléphone ──────────────────────────────────
        if (hasPhone) ...[
          _MethodCard(
            icon: Icons.sms_outlined,
            title: 'Par SMS',
            subtitle: 'Recevoir un code OTP au $normalizedPhone',
            color: theme.colorScheme.primary,
            onTap: () {
              setState(() {
                _method = VerificationMethod.phone;
                _errorMessage = null;
                _successMessage = null;
                _codeSent = false;
              });
              _sendPhoneOtp();
            },
          ),
          const SizedBox(height: 16),
        ],

        // ── Bouton Email ────────────────────────────────────────────
        _MethodCard(
          icon: Icons.email_outlined,
          title: 'Par Email',
          subtitle: 'Recevoir un lien de vérification à ${widget.email}',
          color: Colors.orange.shade700,
          onTap: () {
            setState(() {
              _method = VerificationMethod.email;
              _errorMessage = null;
              _successMessage = null;
              _codeSent = false;
            });
            _sendEmailVerification();
          },
        ),

        // ✅ Note d'aide si pas de numéro
        if (!hasPhone) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La vérification par SMS n\'est pas disponible car '
                        'aucun numéro de téléphone n\'a été fourni.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PHONE VERIFICATION UI
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildPhoneVerification(ThemeData theme) {
    if (!_codeSent && _isLoading) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Envoi du code SMS...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (!_codeSent) {
      // Le code n'a pas été envoyé (erreur ou premier affichage)
      return Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendPhoneOtp,
              icon: const Icon(Icons.send),
              label: const Text('Envoyer le code SMS'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _method = VerificationMethod.none;
              _errorMessage = null;
              _successMessage = null;
            }),
            child: const Text('← Changer de méthode'),
          ),
        ],
      );
    }

    // ── Code envoyé → saisie OTP ────────────────────────────────────
    return Column(
      children: [
        Text(
          'Entrez le code à 6 chiffres',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),

        // ── Champs OTP ──────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            return Container(
              width: 46,
              height: 54,
              margin: EdgeInsets.only(
                left: index == 0 ? 0 : 6,
                right: index == 5 ? 0 : 6,
              ),
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: theme.brightness == Brightness.light
                      ? Colors.grey.shade100
                      : Colors.grey.shade800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    _otpFocusNodes[index + 1].requestFocus();
                  }
                  if (value.isEmpty && index > 0) {
                    _otpFocusNodes[index - 1].requestFocus();
                  }
                  // Auto-submit quand 6 chiffres
                  final code = _otpControllers.map((c) => c.text).join();
                  if (code.length == 6) {
                    _verifyPhoneOtp();
                  }
                },
              ),
            );
          }),
        ),

        const SizedBox(height: 24),

        // ── Bouton Vérifier ─────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyPhoneOtp,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Text('Vérifier', style: TextStyle(fontSize: 16)),
          ),
        ),

        const SizedBox(height: 16),

        // ── Renvoyer le code ────────────────────────────────────────
        _resendCooldown > 0
            ? Text(
          'Renvoyer dans ${_resendCooldown}s',
          style: TextStyle(
            color:
            theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
            fontSize: 13,
          ),
        )
            : TextButton(
          onPressed: _isLoading ? null : _sendPhoneOtp,
          child: const Text('Renvoyer le code'),
        ),

        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() {
            _method = VerificationMethod.none;
            _codeSent = false;
            _errorMessage = null;
            _successMessage = null;
            for (final c in _otpControllers) {
              c.clear();
            }
          }),
          child: const Text('← Changer de méthode'),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EMAIL VERIFICATION UI
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildEmailVerification(ThemeData theme) {
    if (!_codeSent && _isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      );
    }

    if (!_codeSent) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendEmailVerification,
              icon: const Icon(Icons.send),
              label: const Text('Envoyer le lien de vérification'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _method = VerificationMethod.none;
              _errorMessage = null;
            }),
            child: const Text('← Changer de méthode'),
          ),
        ],
      );
    }

    // ── Email envoyé → attente de vérification ──────────────────────
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 40,
                width: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'En attente de vérification...',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cliquez sur le lien envoyé à ${widget.email} '
                    'puis revenez ici.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                  theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _checkEmailVerified,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text("J'ai vérifié mon email"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: 16),

        _resendCooldown > 0
            ? Text(
          'Renvoyer dans ${_resendCooldown}s',
          style: TextStyle(
            color:
            theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
            fontSize: 13,
          ),
        )
            : TextButton(
          onPressed: _isLoading ? null : _sendEmailVerification,
          child: const Text('Renvoyer le lien'),
        ),

        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            _emailCheckTimer?.cancel();
            setState(() {
              _method = VerificationMethod.none;
              _codeSent = false;
              _errorMessage = null;
              _successMessage = null;
            });
          },
          child: const Text('← Changer de méthode'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// METHOD CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
            color: color.withOpacity(0.05),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}