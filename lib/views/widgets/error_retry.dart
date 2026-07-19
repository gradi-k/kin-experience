// lib/views/widgets/error_retry.dart
import 'package:flutter/material.dart';

/// État d'erreur standard avec bouton « Réessayer ».
class ErrorRetryWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  const ErrorRetryWidget({
    super.key,
    this.message = 'Une erreur est survenue.',
    required this.onRetry,
    this.icon = Icons.wifi_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
