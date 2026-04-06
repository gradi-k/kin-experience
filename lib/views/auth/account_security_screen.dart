import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../controllers/dual_auth_controller.dart';

/// Widget pour gérer les méthodes d'authentification liées au compte
class AccountSecurityScreen extends ConsumerStatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  ConsumerState<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends ConsumerState<AccountSecurityScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final hasLinkedAccounts = ref.watch(hasLinkedAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sécurité du compte'),
        backgroundColor: const Color(0xFF0B7A4A),
        foregroundColor: Colors.white,
      ),
      body: hasLinkedAccounts.when(
        data: (hasLinked) => _buildContent(context, authService, hasLinked),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Erreur: $error'),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AuthService authService, bool hasLinked) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // En-tête
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasLinked ? Icons.verified_user : Icons.security,
                      color: hasLinked ? Colors.green : Colors.orange,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasLinked
                                ? 'Compte sécurisé'
                                : 'Sécurité standard',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasLinked
                                ? 'Vous avez lié email et téléphone'
                                : 'Liez email et téléphone pour plus de sécurité',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Section Email
        const Text(
          'Authentification par email',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        Card(
          child: ListTile(
            leading: Icon(
              user.email != null ? Icons.check_circle : Icons.email_outlined,
              color: user.email != null ? Colors.green : Colors.grey,
            ),
            title: Text(user.email ?? 'Non configuré'),
            subtitle: user.email != null
                ? const Text('Email vérifié')
                : const Text('Aucun email lié'),
            trailing: user.email != null
                ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'unlink') {
                  _confirmUnlinkEmail(authService);
                }
              },
              itemBuilder: (context) => [
                if (user.phoneNumber != null)
                  const PopupMenuItem(
                    value: 'unlink',
                    child: Text('Délier l\'email'),
                  ),
              ],
            )
                : IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _showLinkEmailDialog(authService),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Section Téléphone
        const Text(
          'Authentification par téléphone',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        Card(
          child: ListTile(
            leading: Icon(
              user.phoneNumber != null ? Icons.check_circle : Icons.phone_outlined,
              color: user.phoneNumber != null ? Colors.green : Colors.grey,
            ),
            title: Text(user.phoneNumber ?? 'Non configuré'),
            subtitle: user.phoneNumber != null
                ? const Text('Téléphone vérifié')
                : const Text('Aucun téléphone lié'),
            trailing: user.phoneNumber != null
                ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'unlink') {
                  _confirmUnlinkPhone(authService);
                }
              },
              itemBuilder: (context) => [
                if (user.email != null)
                  const PopupMenuItem(
                    value: 'unlink',
                    child: Text('Délier le téléphone'),
                  ),
              ],
            )
                : IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _showLinkPhoneDialog(authService),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Informations supplémentaires
        if (!hasLinked) ...[
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Pourquoi lier les deux ?',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Récupération facile si vous perdez l\'accès\n'
                        '• Sécurité renforcée de votre compte\n'
                        '• Connexion flexible avec email ou téléphone',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOG LIER EMAIL
  // ═══════════════════════════════════════════════════════════════════════════

  void _showLinkEmailDialog(AuthService authService) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Lier un email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ajoutez un email pour sécuriser votre compte',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                if (emailController.text.trim().isEmpty ||
                    passwordController.text.isEmpty) {
                  _showError('Veuillez remplir tous les champs');
                  return;
                }

                setState(() => _isLoading = true);

                try {
                  await authService.linkEmailToAccount(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    _showSuccess('Email lié avec succès !');
                    ref.invalidate(hasLinkedAccountsProvider);
                  }
                } catch (e) {
                  _showError('Erreur: $e');
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Lier'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOG LIER TÉLÉPHONE
  // ═══════════════════════════════════════════════════════════════════════════

  void _showLinkPhoneDialog(AuthService authService) {
    final phoneController = TextEditingController();
    final otpController = TextEditingController();
    String? verificationId;
    int? resendToken;
    bool isOtpSent = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Lier un téléphone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isOtpSent) ...[
                const Text(
                  'Ajoutez un téléphone pour sécuriser votre compte',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone',
                    hintText: '+243 XXX XXX XXX',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                  ],
                ),
              ] else ...[
                const Text(
                  'Entrez le code reçu par SMS',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: otpController,
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
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                if (!isOtpSent) {
                  // Envoyer OTP
                  final phone = phoneController.text.trim();
                  if (phone.isEmpty) {
                    _showError('Entrez un numéro de téléphone');
                    return;
                  }

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
                    await FirebaseAuth.instance.verifyPhoneNumber(
                      phoneNumber: formattedPhone,
                      timeout: const Duration(seconds: 60),
                      verificationCompleted: (credential) async {
                        // Auto-vérification
                        try {
                          await authService.linkPhoneToAccount(
                            verificationId: verificationId!,
                            smsCode: credential.smsCode ?? '',
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            _showSuccess('Téléphone lié !');
                            ref.invalidate(hasLinkedAccountsProvider);
                          }
                        } catch (e) {
                          _showError('Erreur: $e');
                        }
                      },
                      verificationFailed: (e) {
                        if (mounted) {
                          setState(() => _isLoading = false);
                          _showError(e.message ?? 'Erreur de vérification');
                        }
                      },
                      codeSent: (vId, rToken) {
                        if (mounted) {
                          setDialogState(() {
                            verificationId = vId;
                            resendToken = rToken;
                            isOtpSent = true;
                          });
                          setState(() => _isLoading = false);
                          _showSuccess('Code envoyé !');
                        }
                      },
                      codeAutoRetrievalTimeout: (vId) {
                        verificationId = vId;
                      },
                    );
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isLoading = false);
                      _showError('Erreur: $e');
                    }
                  }
                } else {
                  // Vérifier OTP
                  final otp = otpController.text.trim();
                  if (otp.isEmpty || otp.length != 6) {
                    _showError('Code invalide');
                    return;
                  }

                  setState(() => _isLoading = true);

                  try {
                    await authService.linkPhoneToAccount(
                      verificationId: verificationId!,
                      smsCode: otp,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      _showSuccess('Téléphone lié avec succès !');
                      ref.invalidate(hasLinkedAccountsProvider);
                    }
                  } catch (e) {
                    _showError('Code incorrect');
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                }
              },
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Text(isOtpSent ? 'Vérifier' : 'Envoyer le code'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIRMATIONS DÉLIAISON
  // ═══════════════════════════════════════════════════════════════════════════

  void _confirmUnlinkEmail(AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Délier l\'email ?'),
        content: const Text(
          'Vous pourrez toujours vous connecter avec votre téléphone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);

              setState(() => _isLoading = true);

              try {
                await authService.unlinkEmail();
                _showSuccess('Email délié');
                ref.invalidate(hasLinkedAccountsProvider);
              } catch (e) {
                _showError('Erreur: $e');
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Délier'),
          ),
        ],
      ),
    );
  }

  void _confirmUnlinkPhone(AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Délier le téléphone ?'),
        content: const Text(
          'Vous pourrez toujours vous connecter avec votre email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);

              setState(() => _isLoading = true);

              try {
                await authService.unlinkPhone();
                _showSuccess('Téléphone délié');
                ref.invalidate(hasLinkedAccountsProvider);
              } catch (e) {
                _showError('Erreur: $e');
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Délier'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}