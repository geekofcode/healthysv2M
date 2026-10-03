import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../auth/application/session_controller.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final french = Localizations.localeOf(context).languageCode == 'fr';
    final config = ref.watch(appConfigProvider);
    return Scaffold(
      appBar: AppBar(title: Text(french ? 'Paramètres' : 'Settings')),
      body: SafeArea(
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(
                french
                    ? 'Préférences de notification'
                    : 'Notification preferences',
              ),
              onTap: () => context.pushNamed('notification-preferences'),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(french ? 'Mon profil' : 'My profile'),
              onTap: () => context.pushNamed('profile'),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(french ? 'Se déconnecter' : 'Sign out'),
              onTap: () =>
                  ref.read(sessionControllerProvider.notifier).logout(),
            ),
            const ListTile(
              leading: Icon(Icons.health_and_safety_outlined),
              title: Text("HEALTH'YS"),
              subtitle: Text('0.1.0'),
            ),
            if (!config.isProduction)
              ListTile(
                leading: const Icon(Icons.developer_mode),
                title: Text(french ? 'Environnement' : 'Environment'),
                subtitle: Text(config.name),
              ),
          ],
        ),
      ),
    );
  }
}
