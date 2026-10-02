import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/domain/session.dart';
import '../../features/auth/presentation/auth_page.dart';
import '../../features/auth/presentation/profile_page.dart';

import '../../features/home/presentation/home_page.dart';
import '../../features/settings/presentation/settings_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRouterRefresh();
  ref.listen(sessionControllerProvider, (_, _) => refresh.notify());
  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (_, state) {
      final session = ref.read(sessionControllerProvider);
      final onLogin = state.uri.path == '/login';
      if (session.status != SessionStatus.authenticated) {
        if (onLogin) return null;
        final destination = safeReturnPath(state.uri.toString());
        return Uri(
          path: '/login',
          queryParameters: {'from': destination},
        ).toString();
      }
      if (onLogin) return safeReturnPath(state.uri.queryParameters['from']);
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, _) => const AuthPage(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (_, _) => const ProfilePage(),
      ),
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
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Accept only known local destinations; never redirect to external URLs.
String safeReturnPath(String? value) {
  final uri = value == null ? null : Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !const {'/', '/settings', '/profile'}.contains(uri.path)) {
    return '/';
  }
  return uri.path;
}

class _SessionRouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
