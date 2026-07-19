import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/auth_controller.dart';
import '../../localization/app_localizations.dart';
import 'auth_screen.dart';

/// Garde pour les actions qui exigent un compte.
///
/// L'app est consultable sans connexion : la navigation, la recherche, la
/// carte et les fiches sont libres. Seules les actions rattachées à un compte
/// (favoris, avis, likes, profil) passent par ici.
///
/// Retourne `true` si l'action peut se poursuivre — soit l'utilisateur était
/// déjà connecté, soit il vient de se connecter via la feuille.
///
/// Usage :
/// ```dart
/// if (!await requireAuth(context, ref, reason: 'favorites')) return;
/// // ... action nécessitant un compte
/// ```
Future<bool> requireAuth(
  BuildContext context,
  WidgetRef ref, {
  /// Clé de traduction expliquant pourquoi la connexion est demandée.
  String? reason,
}) async {
  if (ref.read(isAuthenticatedProvider)) return true;

  final signedIn = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _SignInPromptSheet(reason: reason),
  );

  if (signedIn != true) return false;

  // La feuille rend la main dès le pop ; authStateChanges peut n'avoir pas
  // encore émis. On relit l'état plutôt que de se fier au résultat du pop.
  return ref.read(isAuthenticatedProvider);
}

class _SignInPromptSheet extends StatelessWidget {
  final String? reason;

  const _SignInPromptSheet({this.reason});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
              child: Icon(
                Icons.lock_outline,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              loc.translate('auth_required_title'),
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              loc.translate(reason ?? 'auth_required_message'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // On empile l'écran d'auth par-dessus la feuille, puis on
                  // referme celle-ci avec le résultat.
                  final navigator = Navigator.of(context);
                  await Navigator.of(context, rootNavigator: true).push<void>(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                  if (navigator.canPop()) navigator.pop(true);
                },
                child: Text(loc.translate('sign_in')),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(loc.translate('continue_as_guest')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
