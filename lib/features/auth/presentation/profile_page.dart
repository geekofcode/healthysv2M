import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/session_controller.dart';
import 'session_issue_message.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final french = Localizations.localeOf(context).languageCode == 'fr';
    final session = ref.watch(sessionControllerProvider);
    final profile = session.profile;
    return Scaffold(
      appBar: AppBar(title: Text(french ? 'Mon profil' : 'My profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (profile == null && session.error == null)
              const Center(child: CircularProgressIndicator()),
            if (session.error != null) ...[
              Text(sessionIssueMessage(session.issue, french: french)),
              TextButton(
                onPressed: () => ref
                    .read(sessionControllerProvider.notifier)
                    .reloadProfile(),
                child: Text(french ? 'Réessayer' : 'Try again'),
              ),
            ],
            if (profile != null) ...[
              if (profile.displayName.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(profile.displayName),
                ),
              if (profile.data['personNumber'] case final String number)
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(french ? 'Numéro de personne' : 'Person number'),
                  subtitle: Text(number),
                ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(sessionControllerProvider.notifier).logout(),
              icon: const Icon(Icons.logout),
              label: Text(french ? 'Se déconnecter' : 'Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
