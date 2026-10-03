import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/healthys_theme.dart';
import '../features/notifications/application/push_controller.dart';
import '../features/notifications/application/notification_providers.dart';
import '../features/auth/application/session_controller.dart';

class HealthysApp extends ConsumerStatefulWidget {
  const HealthysApp({super.key});

  @override
  ConsumerState<HealthysApp> createState() => _HealthysAppState();
}

class _HealthysAppState extends ConsumerState<HealthysApp>
    with WidgetsBindingObserver {
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(pushControllerProvider.notifier).resume());
    }
  }

  Future<void> _openPending() async {
    if (_opening || !ref.read(sessionControllerProvider).isAuthenticated) {
      return;
    }
    final id = ref.read(pushControllerProvider).pendingNotificationId;
    if (id == null) {
      return;
    }
    _opening = true;
    final person = ref.read(sessionControllerProvider).profile?.id;
    try {
      final destination = await ref.read(notificationActionsProvider).open(id);
      if (mounted &&
          ref.read(sessionControllerProvider).isAuthenticated &&
          ref.read(sessionControllerProvider).profile?.id == person) {
        ref.read(pushControllerProvider.notifier).consumePending(id);
        ref.read(appRouterProvider).go(destination);
      }
    } catch (_) {
      if (mounted) {
        ref.read(pushControllerProvider.notifier).consumePending(id);
      }
    } finally {
      _opening = false;
      if (mounted &&
          ref.read(pushControllerProvider).pendingNotificationId != null &&
          ref.read(pushControllerProvider).pendingNotificationId != id) {
        unawaited(_openPending());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(pushControllerProvider);
    ref.listen(pushControllerProvider, (previous, next) {
      if (next.pendingNotificationId != null) {
        unawaited(_openPending());
      }
    });
    ref.listen(sessionControllerProvider, (_, next) {
      if (next.isAuthenticated) {
        unawaited(_openPending());
      }
    });
    return MaterialApp.router(
      title: "HEALTH'YS",
      debugShowCheckedModeBanner: false,
      theme: HealthysTheme.light,
      darkTheme: HealthysTheme.dark,
      supportedLocales: const [Locale('en'), Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) =>
          _ForegroundNotification(child: child ?? const SizedBox.shrink()),
    );
  }
}

class _ForegroundNotification extends ConsumerWidget {
  const _ForegroundNotification({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(pushControllerProvider, (previous, next) {
      if (next.foregroundRevision != (previous?.foregroundRevision ?? 0) &&
          ref.read(sessionControllerProvider).isAuthenticated) {
        final french = Localizations.localeOf(context).languageCode == 'fr';
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              french
                  ? 'Nouvelle notification HEALTH’YS'
                  : 'New HEALTH’YS notification',
            ),
            action: SnackBarAction(
              label: french ? 'Voir' : 'View',
              onPressed: () => ref.read(appRouterProvider).go('/notifications'),
            ),
          ),
        );
      }
    });
    return child;
  }
}
