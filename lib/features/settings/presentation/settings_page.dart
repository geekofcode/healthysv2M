import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';

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
