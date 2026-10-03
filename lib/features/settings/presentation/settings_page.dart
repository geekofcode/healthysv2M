import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../auth/application/session_controller.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final french = Localizations.localeOf(context).languageCode == 'fr';
    final config = ref.watch(appConfigProvider);
    final preferences = ref.watch(appPreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(french ? 'Paramètres' : 'Settings')),
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                french ? 'Apparence et langue' : 'Appearance and language',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(french ? 'Thème' : 'Theme'),
              subtitle: DropdownButton<ThemeMode>(
                key: const Key('theme-preference'),
                value: preferences.themeMode,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text(french ? 'Selon le système' : 'System default'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text(french ? 'Clair' : 'Light'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text(french ? 'Sombre' : 'Dark'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(appPreferencesProvider.notifier)
                        .setThemeMode(value);
                  }
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(french ? 'Langue' : 'Language'),
              subtitle: DropdownButton<AppLanguage>(
                key: const Key('language-preference'),
                value: preferences.language,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: AppLanguage.system,
                    child: Text(french ? 'Selon le système' : 'System default'),
                  ),
                  const DropdownMenuItem(
                    value: AppLanguage.french,
                    child: Text('Français'),
                  ),
                  const DropdownMenuItem(
                    value: AppLanguage.english,
                    child: Text('English'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(appPreferencesProvider.notifier)
                        .setLanguage(value);
                  }
                },
              ),
            ),
            if (preferences.storageFailed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  french
                      ? 'Préférences non enregistrées. Réessayez votre choix.'
                      : 'Preferences could not be saved. Please select again.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const Divider(),
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
