import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';

enum AppLanguage { system, french, english }

class AppPreferences {
  const AppPreferences({
    this.themeMode = ThemeMode.system,
    this.language = AppLanguage.system,
    this.restoring = false,
    this.storageFailed = false,
  });

  final ThemeMode themeMode;
  final AppLanguage language;
  final bool restoring;
  final bool storageFailed;

  Locale? get locale => switch (language) {
    AppLanguage.system => null,
    AppLanguage.french => const Locale('fr'),
    AppLanguage.english => const Locale('en'),
  };

  Map<String, String> toJson() => {
    'theme': themeMode.name,
    'language': language.name,
  };

  factory AppPreferences.fromJson(Map<String, dynamic> value) => AppPreferences(
    themeMode: ThemeMode.values.firstWhere(
      (mode) => mode.name == value['theme'],
      orElse: () => ThemeMode.system,
    ),
    language: AppLanguage.values.firstWhere(
      (language) => language.name == value['language'],
      orElse: () => AppLanguage.system,
    ),
  );
}

abstract interface class AppPreferencesStore {
  Future<AppPreferences?> read();
  Future<void> write(AppPreferences preferences);
}

/// Separate keys from session credentials: signing out preserves appearance.
class SecureAppPreferencesStore implements AppPreferencesStore {
  SecureAppPreferencesStore(this.storage, {required this.environment});
  final FlutterSecureStorage storage;
  final String environment;
  String get _key => 'healthys.$environment.preferences.v1';

  @override
  Future<AppPreferences?> read() async {
    final value = await storage.read(key: _key);
    if (value == null) return null;
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid application preferences');
    }
    return AppPreferences.fromJson(decoded);
  }

  @override
  Future<void> write(AppPreferences preferences) =>
      storage.write(key: _key, value: jsonEncode(preferences.toJson()));
}

final appPreferencesStoreProvider = Provider<AppPreferencesStore>((ref) {
  return SecureAppPreferencesStore(
    const FlutterSecureStorage(),
    environment: ref.watch(appConfigProvider).name,
  );
});

final appPreferencesProvider =
    NotifierProvider<AppPreferencesController, AppPreferences>(
      AppPreferencesController.new,
    );

class AppPreferencesController extends Notifier<AppPreferences> {
  int _revision = 0;
  bool _disposed = false;
  Future<void> _writes = Future<void>.value();

  @override
  AppPreferences build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_restore());
    return const AppPreferences(restoring: true);
  }

  Future<void> _restore() async {
    final revision = _revision;
    try {
      final preferences = await ref.read(appPreferencesStoreProvider).read();
      if (!_disposed && revision == _revision) {
        state = preferences ?? const AppPreferences();
      }
    } catch (_) {
      if (!_disposed && revision == _revision) {
        state = const AppPreferences(storageFailed: true);
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) => _update(themeMode: mode);

  Future<void> setLanguage(AppLanguage language) => _update(language: language);

  Future<void> _update({ThemeMode? themeMode, AppLanguage? language}) {
    final revision = ++_revision;
    final preferences = AppPreferences(
      themeMode: themeMode ?? state.themeMode,
      language: language ?? state.language,
    );
    state = preferences;
    final store = ref.read(appPreferencesStoreProvider);
    // Serialize saves so a slow older write cannot replace a newer choice.
    _writes = _writes.then((_) async {
      try {
        await store.write(preferences);
      } catch (_) {
        if (!_disposed && revision == _revision) {
          state = AppPreferences(
            themeMode: preferences.themeMode,
            language: preferences.language,
            storageFailed: true,
          );
        }
      }
    });
    return _writes;
  }
}
