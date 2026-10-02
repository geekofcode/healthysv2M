import 'package:flutter/material.dart';

import 'app_exception.dart';

/// Reusable error state. Backend messages may contain diagnostic information;
/// display localized, controlled copy and a support identifier instead.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final AppException error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final french = Localizations.localeOf(context).languageCode == 'fr';
    final message = localizedErrorMessage(error.kind, french: french);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (error.correlationId case final String id) ...[
              const SizedBox(height: 8),
              SelectableText(
                '${french ? 'Référence' : 'Reference'} : $id',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: Text(french ? 'Réessayer' : 'Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String localizedErrorMessage(AppErrorKind kind, {required bool french}) {
  if (french) {
    return switch (kind) {
      AppErrorKind.network => 'Connexion indisponible. Vérifiez votre réseau.',
      AppErrorKind.timeout => 'Le serveur met trop de temps à répondre.',
      AppErrorKind.unauthorized => 'Votre session a expiré. Reconnectez-vous.',
      AppErrorKind.forbidden => 'Vous ne disposez pas des droits nécessaires.',
      AppErrorKind.validation => 'Vérifiez les informations saisies.',
      AppErrorKind.server => 'Le service est temporairement indisponible.',
      AppErrorKind.cancelled => 'La demande a été annulée.',
      AppErrorKind.unknown => 'Une erreur est survenue. Réessayez.',
    };
  }
  return switch (kind) {
    AppErrorKind.network => 'Connection unavailable. Check your network.',
    AppErrorKind.timeout => 'The server is taking too long to respond.',
    AppErrorKind.unauthorized => 'Your session has expired. Sign in again.',
    AppErrorKind.forbidden =>
      'You do not have permission to perform this action.',
    AppErrorKind.validation => 'Check the information you entered.',
    AppErrorKind.server => 'The service is temporarily unavailable.',
    AppErrorKind.cancelled => 'The request was cancelled.',
    AppErrorKind.unknown => 'Something went wrong. Try again.',
  };
}
