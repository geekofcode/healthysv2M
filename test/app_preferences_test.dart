import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/preferences/app_preferences.dart';
import 'package:healthysv2/app/theme/healthys_theme.dart';

class _PreferencesStore implements AppPreferencesStore {
  AppPreferences? saved;
  final pendingRead = Completer<AppPreferences?>();
  bool failWrite = false;
  final writes = <AppPreferences>[];
  @override
  Future<AppPreferences?> read() => pendingRead.future;
  @override
  Future<void> write(AppPreferences preferences) async {
    if (failWrite) throw StateError('Storage unavailable');
    writes.add(preferences);
    saved = preferences;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('both themes provide readable secondary controls', () {
    for (final theme in [HealthysTheme.light, HealthysTheme.dark]) {
      final first = theme.colorScheme.secondary.computeLuminance();
      final second = theme.colorScheme.onSecondary.computeLuminance();
      final high = first > second ? first : second;
      final low = first < second ? first : second;
      expect((high + 0.05) / (low + 0.05), greaterThanOrEqualTo(4.5));
    }
  });

  test('unsupported preferences safely use system defaults', () {
    final preferences = AppPreferences.fromJson({
      'theme': 'invalid',
      'language': 123,
    });
    expect(preferences.themeMode, ThemeMode.system);
    expect(preferences.locale, isNull);
  });

  test('restores stored theme and locale', () async {
    final store = _PreferencesStore();
    final container = ProviderContainer(
      overrides: [appPreferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    expect(container.read(appPreferencesProvider).restoring, isTrue);
    store.pendingRead.complete(
      const AppPreferences(
        themeMode: ThemeMode.dark,
        language: AppLanguage.french,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final preferences = container.read(appPreferencesProvider);
    expect(preferences.restoring, isFalse);
    expect(preferences.themeMode, ThemeMode.dark);
    expect(preferences.locale, const Locale('fr'));
  });

  test('late restoration cannot overwrite an explicit user choice', () async {
    final store = _PreferencesStore();
    final container = ProviderContainer(
      overrides: [appPreferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final controller = container.read(appPreferencesProvider.notifier);
    await controller.setThemeMode(ThemeMode.light);
    store.pendingRead.complete(const AppPreferences(themeMode: ThemeMode.dark));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appPreferencesProvider).themeMode, ThemeMode.light);
    expect(store.saved?.themeMode, ThemeMode.light);
  });

  test('storage read failure keeps safe defaults without throwing', () async {
    final store = _PreferencesStore();
    final container = ProviderContainer(
      overrides: [appPreferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    container.read(appPreferencesProvider);
    store.pendingRead.completeError(StateError('Storage unavailable'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appPreferencesProvider).themeMode, ThemeMode.system);
    expect(container.read(appPreferencesProvider).storageFailed, isTrue);
  });

  test('failed save is visible and a subsequent choice recovers', () async {
    final store = _PreferencesStore()..failWrite = true;
    final container = ProviderContainer(
      overrides: [appPreferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final controller = container.read(appPreferencesProvider.notifier);
    store.pendingRead.complete(null);
    await Future<void>.delayed(Duration.zero);
    await controller.setLanguage(AppLanguage.french);
    expect(container.read(appPreferencesProvider).storageFailed, isTrue);
    expect(container.read(appPreferencesProvider).locale, const Locale('fr'));
    store.failWrite = false;
    await controller.setLanguage(AppLanguage.english);
    expect(container.read(appPreferencesProvider).storageFailed, isFalse);
    expect(store.saved?.locale, const Locale('en'));
  });

  test('rapid choices are persisted in order with combined settings', () async {
    final store = _PreferencesStore();
    final container = ProviderContainer(
      overrides: [appPreferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final controller = container.read(appPreferencesProvider.notifier);
    final first = controller.setThemeMode(ThemeMode.dark);
    final second = controller.setLanguage(AppLanguage.french);
    final third = controller.setThemeMode(ThemeMode.light);
    await Future.wait([first, second, third]);
    expect(store.writes.map((value) => value.themeMode), [
      ThemeMode.dark,
      ThemeMode.dark,
      ThemeMode.light,
    ]);
    expect(store.saved?.locale, const Locale('fr'));
    store.pendingRead.complete(null);
  });

  test('preferences persist separately for dev and prod', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final dev = SecureAppPreferencesStore(
      const FlutterSecureStorage(),
      environment: 'dev',
    );
    final prod = SecureAppPreferencesStore(
      const FlutterSecureStorage(),
      environment: 'prod',
    );
    await dev.write(
      const AppPreferences(
        themeMode: ThemeMode.dark,
        language: AppLanguage.french,
      ),
    );
    expect((await dev.read())?.themeMode, ThemeMode.dark);
    expect((await dev.read())?.locale, const Locale('fr'));
    expect(await prod.read(), isNull);
  });
}
