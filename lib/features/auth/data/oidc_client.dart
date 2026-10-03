import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import '../../../core/config/app_config.dart';
import '../domain/session.dart';

class AppAuthOidcClient implements OidcClient {
  AppAuthOidcClient(this.config, {FlutterAppAuth? appAuth})
    : _appAuth = appAuth ?? const FlutterAppAuth();
  final AppConfig config;
  final FlutterAppAuth _appAuth;
  static const scopes = ['openid', 'profile', 'email'];
  @override
  Future<SessionTokens> login() async {
    try {
      final response = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          config.oidcClientId,
          config.oidcRedirectUri,
          issuer: config.issuer.toString(),
          scopes: scopes,
          promptValues: ['login'],
        ),
      );
      return _tokens(response);
    } on PlatformException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<SessionTokens> refresh(SessionTokens previous) async {
    try {
      final response = await _appAuth.token(
        TokenRequest(
          config.oidcClientId,
          config.oidcRedirectUri,
          issuer: config.issuer.toString(),
          refreshToken: previous.refreshToken,
          scopes: scopes,
        ),
      );
      return _tokens(response, previous);
    } on PlatformException catch (e) {
      throw _failure(e);
    }
  }

  SessionTokens _tokens(TokenResponse response, [SessionTokens? previous]) {
    final access = response.accessToken;
    final expiry = response.accessTokenExpirationDateTime;
    if (access == null || access.isEmpty || expiry == null) {
      throw const OidcFailure();
    }
    return SessionTokens(
      accessToken: access,
      expiresAt: expiry,
      refreshToken: response.refreshToken ?? previous?.refreshToken,
      idToken: response.idToken ?? previous?.idToken,
    );
  }

  OidcFailure _failure(PlatformException e) {
    if (e is FlutterAppAuthUserCancelledException) {
      return const OidcFailure(cancelled: true);
    }
    if (e is FlutterAppAuthPlatformException) {
      return OidcFailure(
        invalidGrant:
            e.platformErrorDetails.error ==
            FlutterAppAuthOAuthError.invalidGrant,
      );
    }
    return OidcFailure(
      invalidGrant: e.code == FlutterAppAuthOAuthError.invalidGrant,
    );
  }

  @override
  Future<void> logout(String? idToken) async {
    await _appAuth.endSession(
      EndSessionRequest(
        issuer: config.issuer.toString(),
        idTokenHint: idToken,
        postLogoutRedirectUrl: config.oidcPostLogoutRedirectUri,
        additionalParameters: {'client_id': config.oidcClientId},
      ),
    );
  }
}
