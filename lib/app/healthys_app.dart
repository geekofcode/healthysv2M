import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/healthys_theme.dart';

class HealthysApp extends ConsumerWidget {
  const HealthysApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: "HEALTH'YS",
    debugShowCheckedModeBanner: false,
    theme: HealthysTheme.light,
    darkTheme: HealthysTheme.dark,
    supportedLocales: const [Locale('en'), Locale('fr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: ref.watch(appRouterProvider),
  );
}
