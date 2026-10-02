import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironment { dev, prod }

class AppConfig {
  AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    Uri? issuer,
    this.oidcClientId = 'healthys-mobile-apps',
    this.oidcRedirectUri = 'healthys://oauth/callback',
    this.oidcPostLogoutRedirectUri = 'healthys://oauth/callback',
  }) : issuer =
           issuer ?? Uri.parse('https://keycloak.wouri.tv/realms/healthys') {
    if (this.issuer.scheme != 'https' ||
        !this.issuer.hasAuthority ||
        this.issuer.userInfo.isNotEmpty ||
        this.issuer.hasQuery ||
        this.issuer.hasFragment ||
        oidcClientId.trim().isEmpty) {
      throw ArgumentError('OIDC exige un issuer HTTPS et un client public.');
    }
    for (final redirect in [oidcRedirectUri, oidcPostLogoutRedirectUri]) {
      if (redirect != 'healthys://oauth/callback') {
        throw ArgumentError(
          'Le callback enregistré doit être healthys://oauth/callback.',
        );
      }
    }
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
      issuer: const String.fromEnvironment(
        'OIDC_ISSUER',
        defaultValue: 'https://keycloak.wouri.tv/realms/healthys',
      ),
      oidcClientId: const String.fromEnvironment(
        'OIDC_CLIENT_ID',
        defaultValue: 'healthys-mobile-apps',
      ),
      oidcRedirectUri: const String.fromEnvironment(
        'OIDC_REDIRECT_URI',
        defaultValue: 'healthys://oauth/callback',
      ),
      oidcPostLogoutRedirectUri: const String.fromEnvironment(
        'OIDC_POST_LOGOUT_REDIRECT_URI',
        defaultValue: 'healthys://oauth/callback',
      ),
    );
    if (kReleaseMode && !config.isProduction) {
      throw StateError('Un build release exige APP_ENV=prod.');
    }
    return config;
  }

  factory AppConfig.fromValues({
    required String environment,
    required String apiBaseUrl,
    String issuer = 'https://keycloak.wouri.tv/realms/healthys',
    String oidcClientId = 'healthys-mobile-apps',
    String oidcRedirectUri = 'healthys://oauth/callback',
    String oidcPostLogoutRedirectUri = 'healthys://oauth/callback',
  }) {
    final env = AppEnvironment.values.where((e) => e.name == environment);
    if (env.isEmpty) throw ArgumentError('APP_ENV doit valoir dev ou prod.');
    if (apiBaseUrl.trim().isEmpty && environment == 'prod') {
      throw ArgumentError('API_BASE_URL est obligatoire en production.');
    }
    return AppConfig(
      environment: env.single,
      issuer: Uri.parse(issuer),
      oidcClientId: oidcClientId,
      oidcRedirectUri: oidcRedirectUri,
      oidcPostLogoutRedirectUri: oidcPostLogoutRedirectUri,
      apiBaseUrl: Uri.parse(
        apiBaseUrl.trim().isEmpty ? 'http://10.0.2.2:8080/api/v1' : apiBaseUrl,
      ),
    );
  }

  final AppEnvironment environment;
  final Uri apiBaseUrl;
  final Uri issuer;
  final String oidcClientId;
  final String oidcRedirectUri;
  final String oidcPostLogoutRedirectUri;
  List<String> get oidcScopes => const ['openid', 'profile', 'email'];
  bool get isProduction => environment == AppEnvironment.prod;
  String get name => environment.name;
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw StateError('AppConfig doit être injectée au démarrage.'),
);
