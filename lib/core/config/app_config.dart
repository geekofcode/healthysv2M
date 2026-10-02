import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironment { dev, prod }

class AppConfig {
  AppConfig({required this.environment, required this.apiBaseUrl}) {
    if (!apiBaseUrl.hasAuthority ||
        !{'http', 'https'}.contains(apiBaseUrl.scheme) ||
        apiBaseUrl.userInfo.isNotEmpty ||
        apiBaseUrl.hasQuery ||
        apiBaseUrl.hasFragment) {
      throw ArgumentError('API_BASE_URL doit être une URL HTTP(S) absolue.');
    }
    if (isProduction && apiBaseUrl.scheme != 'https') {
      throw ArgumentError('La production exige HTTPS.');
    }
    if (!apiBaseUrl.path.endsWith('/api/v1') &&
        !apiBaseUrl.path.endsWith('/api/v1/')) {
      throw ArgumentError('API_BASE_URL doit se terminer par /api/v1.');
    }
  }

  factory AppConfig.fromEnvironment() {
    final config = AppConfig.fromValues(
      environment: const String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    );
    if (kReleaseMode && !config.isProduction) {
      throw StateError('Un build release exige APP_ENV=prod.');
    }
    return config;
  }

  factory AppConfig.fromValues({
    required String environment,
    required String apiBaseUrl,
  }) {
    final env = AppEnvironment.values.where((e) => e.name == environment);
    if (env.isEmpty) throw ArgumentError('APP_ENV doit valoir dev ou prod.');
    if (apiBaseUrl.trim().isEmpty && environment == 'prod') {
      throw ArgumentError('API_BASE_URL est obligatoire en production.');
    }
    return AppConfig(
      environment: env.single,
      apiBaseUrl: Uri.parse(
        apiBaseUrl.trim().isEmpty ? 'http://10.0.2.2:8080/api/v1' : apiBaseUrl,
      ),
    );
  }

  final AppEnvironment environment;
  final Uri apiBaseUrl;
  bool get isProduction => environment == AppEnvironment.prod;
  String get name => environment.name;
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw StateError('AppConfig doit être injectée au démarrage.'),
);
