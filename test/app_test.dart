import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/app/healthys_app.dart';
import 'package:healthysv2/core/config/app_config.dart';
import 'package:healthysv2/core/preferences/app_preferences.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/patient/application/patient_dashboard_provider.dart';

class _AuthenticatedSession extends SessionController {
  @override
  SessionState build() =>
      const SessionState(status: SessionStatus.authenticated);
}

class _MemoryPreferences implements AppPreferencesStore {
  AppPreferences? saved;
  @override
  Future<AppPreferences?> read() async => saved;
  @override
  Future<void> write(AppPreferences value) async => saved = value;
}

void main() {
  testWidgets('home opens settings and returns', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesStoreProvider.overrideWithValue(_MemoryPreferences()),
          patientDashboardProvider.overrideWith((ref) async => null),
          sessionControllerProvider.overrideWith(_AuthenticatedSession.new),
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(environment: 'dev', apiBaseUrl: ''),
          ),
        ],
        child: const HealthysApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("HEALTH'YS"), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('dev'), 200);
    expect(find.text('dev'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('My patient dashboard'), findsOneWidget);
  });
  testWidgets('changing theme and language preserves the settings route', (
    tester,
  ) async {
    final store = _MemoryPreferences();
    final container = ProviderContainer(
      overrides: [
        appPreferencesStoreProvider.overrideWithValue(store),
        patientDashboardProvider.overrideWith((ref) async => null),
        sessionControllerProvider.overrideWith(_AuthenticatedSession.new),
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(environment: 'dev', apiBaseUrl: ''),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HealthysApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-preference')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Français').last);
    await tester.pumpAndSettle();
    expect(find.text('Paramètres'), findsOneWidget);
    expect(find.text('Apparence et langue'), findsOneWidget);
    await tester.tap(find.byKey(const Key('theme-preference')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sombre').last);
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Paramètres'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(Localizations.localeOf(context), const Locale('fr'));
    expect(store.saved?.themeMode, ThemeMode.dark);
    expect(store.saved?.language, AppLanguage.french);
    await container
        .read(appPreferencesProvider.notifier)
        .setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Paramètres'))).brightness,
      Brightness.light,
    );
    // pageBack searches the English tooltip; the app is now in French.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}
