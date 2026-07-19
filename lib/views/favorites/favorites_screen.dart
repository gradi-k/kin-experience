import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../localization/app_localizations.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/favorites_controller.dart';
import '../auth/auth_guard.dart';
import '../widgets/place_card.dart';
import '../widgets/error_retry.dart';
import '../widgets/skeletons.dart';
import '../detail_screen.dart';

/// Liste des lieux mis en favori par l'utilisateur.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final favoritesAsync = ref.watch(favoritesControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('nav_favorites')),
      ),
      body: !isAuthenticated
          ? _GuestPrompt(
              message: loc.translate('auth_required_favorites'),
              buttonLabel: loc.translate('sign_in'),
              onPressed: () => requireAuth(
                context,
                ref,
                reason: 'auth_required_favorites',
              ),
            )
          : favoritesAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return Center(child: Text(loc.translate('no_results')));
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(favoritesControllerProvider),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: PlaceCard(
                          place: item,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DetailScreen(place: item),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const ListSkeleton(),
              error: (e, st) => ErrorRetryWidget(
                message: 'Impossible de charger vos favoris.',
                onRetry: () => ref.invalidate(favoritesControllerProvider),
              ),
            ),
    );
  }
}

/// État affiché à un visiteur non connecté.
class _GuestPrompt extends StatelessWidget {
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _GuestPrompt({
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: 72,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
