import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/presentation/session_issue_message.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final french = Localizations.localeOf(context).languageCode == 'fr';
    final session = ref.watch(sessionControllerProvider);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text("HEALTH'YS"),
        actions: [
          IconButton(
            onPressed: () => context.pushNamed('profile'),
            tooltip: french ? 'Profil' : 'Profile',
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            onPressed: () => context.pushNamed('settings'),
            tooltip: french ? 'Paramètres' : 'Settings',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (session.error != null) ...[
                    Text(
                      sessionIssueMessage(session.issue, french: french),
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(sessionControllerProvider.notifier)
                          .reloadProfile(),
                      child: Text(french ? 'Réessayer' : 'Try again'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Icon(
                    Icons.health_and_safety_outlined,
                    size: 80,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    french
                        ? 'Votre santé, à vos côtés'
                        : 'Your health, by your side',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    french
                        ? "Bienvenue sur HEALTH'YS. Votre espace de santé mobile prend forme."
                        : "Welcome to HEALTH'YS. Your mobile health space is taking shape.",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
