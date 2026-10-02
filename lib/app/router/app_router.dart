import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_page.dart';
import '../../features/settings/presentation/settings_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', name: 'home', builder: (_, _) => const HomePage()),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (_, _) => const SettingsPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text("HEALTH'YS")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Localizations.localeOf(context).languageCode == 'fr'
                  ? 'Page introuvable'
                  : 'Page not found',
            ),
            TextButton(
              onPressed: () => context.go('/'),
              child: Text(
                Localizations.localeOf(context).languageCode == 'fr'
                    ? 'Accueil'
                    : 'Home',
              ),
            ),
          ],
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});
