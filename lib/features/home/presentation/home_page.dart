import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final french = Localizations.localeOf(context).languageCode == 'fr';
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text("HEALTH'YS"),
        actions: [
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
