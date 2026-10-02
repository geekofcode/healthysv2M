import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/config/app_config.dart';
import 'package:healthysv2/features/auth/data/oidc_client.dart';
import 'package:healthysv2/features/auth/domain/session.dart';

class FailingAppAuth extends FlutterAppAuth {
  FailingAppAuth(this.failure);
  final Object failure;
  @override
  Future<TokenResponse> token(TokenRequest request) async => throw failure;
  @override
  Future<AuthorizationTokenResponse> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  ) async => throw failure;
}

void main() {
  final config = AppConfig.fromValues(environment: 'dev', apiBaseUrl: '');
  test(
    'structured invalid_grant expires token instead of treating as connectivity',
    () async {
      final appAuth = FailingAppAuth(
        FlutterAppAuthPlatformException(
          code: 'token_failed',
          platformErrorDetails: FlutterAppAuthPlatformErrorDetails(
            error: 'invalid_grant',
          ),
        ),
      );
      final client = AppAuthOidcClient(config, appAuth: appAuth);
      await expectLater(
        client.refresh(
          SessionTokens(
            accessToken: 'old',
            refreshToken: 'refresh',
            expiresAt: DateTime.utc(2026),
          ),
        ),
        throwsA(
          isA<OidcFailure>().having(
            (e) => e.invalidGrant,
            'invalidGrant',
            true,
          ),
        ),
      );
    },
  );
  test('typed cancellation closes browser without login error', () async {
    final appAuth = FailingAppAuth(
      FlutterAppAuthUserCancelledException(
        code: 'unexpected_code',
        platformErrorDetails: FlutterAppAuthPlatformErrorDetails(),
      ),
    );
    final client = AppAuthOidcClient(config, appAuth: appAuth);
    await expectLater(
      client.login(),
      throwsA(isA<OidcFailure>().having((e) => e.cancelled, 'cancelled', true)),
    );
  });
}
