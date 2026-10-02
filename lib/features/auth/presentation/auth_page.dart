import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/session_controller.dart';
import '../domain/session.dart';
import 'session_issue_message.dart';

class AuthPage extends ConsumerWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final french = Localizations.localeOf(context).languageCode == 'fr';
    final session = ref.watch(sessionControllerProvider);
    final busy =
        session.status == SessionStatus.restoring ||
        session.status == SessionStatus.authenticating;
    return Scaffold(
      appBar: AppBar(title: const Text("HEALTH'YS")),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.health_and_safety_outlined,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    french ? 'Votre espace santé' : 'Your health space',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  if (busy) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      session.status == SessionStatus.restoring
                          ? (french
                                ? 'Restauration de la session…'
                                : 'Restoring your session…')
                          : (french ? 'Connexion en cours…' : 'Signing in…'),
                    ),
                  ] else ...[
                    if (session.status == SessionStatus.expired)
                      Text(
                        french
                            ? 'Votre session a expiré. Reconnectez-vous.'
                            : 'Your session has expired. Sign in again.',
                        textAlign: TextAlign.center,
                      ),
                    if (session.error != null) ...[
                      Text(
                        sessionIssueMessage(session.issue, french: french),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () {
                          final controller = ref.read(
                            sessionControllerProvider.notifier,
                          );
                          if (session.logoutFailed ||
                              session.issue == SessionIssue.remoteLogout) {
                            controller.logout();
                          } else {
                            controller.restore();
                          }
                        },
                        child: Text(french ? 'Réessayer' : 'Try again'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          ref.read(sessionControllerProvider.notifier).login(),
                      icon: const Icon(Icons.login),
                      label: Text(french ? 'Se connecter' : 'Sign in'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      french
                          ? 'La connexion sécurisée s’ouvre dans votre navigateur.'
                          : 'Secure sign-in opens in your browser.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
