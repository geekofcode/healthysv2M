import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/storage/token_store.dart';
import 'package:healthysv2/features/auth/domain/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  const storage = FlutterSecureStorage();
  final tokens = SessionTokens(
    accessToken: 'access',
    refreshToken: 'refresh',
    idToken: 'identity',
    expiresAt: DateTime.utc(2026, 10, 2, 16),
  );
  test(
    'session bundle persists all credentials with a single secure key',
    () async {
      final store = SecureTokenStore(storage, namespace: 'dev');
      await store.writeSession(tokens);
      expect((await storage.readAll()).length, 1);
      final restored = await store.readSession();
      expect(restored?.refreshToken, 'refresh');
      expect(restored?.idToken, 'identity');
      expect(restored?.expiresAt, tokens.expiresAt);
      expect(await store.readAccessToken(), 'access');
    },
  );
  test('clearing one environment preserves other environments', () async {
    final dev = SecureTokenStore(storage, namespace: 'dev');
    final prod = SecureTokenStore(storage, namespace: 'prod');
    await dev.writeSession(tokens);
    await prod.writeSession(tokens);
    await dev.clear();
    expect(await dev.readAccessToken(), isNull);
    expect(await prod.readAccessToken(), 'access');
  });
  for (final corrupt in [
    '{invalid-json',
    '[]',
    '{"accessToken":42,"expiresAt":"2026-10-02T16:00:00Z"}',
    '{"accessToken":"","expiresAt":"2026-10-02T16:00:00Z"}',
    '{"accessToken":"secret","expiresAt":"2026-10-02T16:00:00"}',
    '{"accessToken":"secret","expiresAt":"invalid"}',
    '{"accessToken":"secret","expiresAt":"2026-10-02T16:00:00Z","refreshToken":42}',
  ]) {
    test(
      'corrupt secure bundle is cleared without legacy fallback: $corrupt',
      () async {
        final dev = SecureTokenStore(storage, namespace: 'dev');
        final prod = SecureTokenStore(storage, namespace: 'prod');
        await storage.write(key: 'healthys.dev.session.v1', value: corrupt);
        await dev.writeAccessToken('legacy-secret');
        await prod.writeSession(tokens);
        expect(await dev.readAccessToken(), isNull);
        expect(await storage.read(key: 'healthys.dev.session.v1'), isNull);
        expect(await storage.read(key: 'healthys.dev.access_token'), isNull);
        expect(await prod.readAccessToken(), 'access');
      },
    );
  }

  test('session diagnostics redact all credentials', () {
    final diagnostic = tokens.toString();
    expect(diagnostic, contains('redacted'));
    expect(diagnostic, isNot(contains('refresh')));
    expect(diagnostic, isNot(contains('identity')));
    expect(diagnostic, isNot(contains('access')));
  });
}
