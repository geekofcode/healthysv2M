import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/storage/token_store.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';

class MemoryStore implements SessionTokenStore {
  SessionTokens? tokens;
  @override
  Future<void> clear() async {
    tokens = null;
  }

  @override
  Future<String?> readAccessToken() async => tokens?.accessToken;
  @override
  Future<void> writeAccessToken(String token) async {}
  @override
  Future<SessionTokens?> readSession() async => tokens;
  @override
  Future<void> writeSession(SessionTokens value) async {
    tokens = value;
  }
}

class FakeOidc implements OidcClient {
  int refreshes = 0;
  Object? failure;
  Completer<SessionTokens>? pending;
  final now = DateTime.utc(2026);
  SessionTokens get fresh => SessionTokens(
    accessToken: 'fresh',
    refreshToken: 'rotated',
    expiresAt: now.add(const Duration(hours: 1)),
  );
  @override
  Future<SessionTokens> login() async => fresh;
  @override
  Future<void> logout(String? idToken) async {
    throw const OidcFailure();
  }

  @override
  Future<SessionTokens> refresh(SessionTokens previous) async {
    refreshes++;
    if (failure != null) throw failure!;
    return pending == null ? fresh : pending!.future;
  }
}

class FakeProfile implements ProfileClient {
  Completer<MobileProfile>? pending;
  @override
  Future<MobileProfile> fetch(String token) async {
    final next = pending;
    pending = null;
    return next == null
        ? const MobileProfile({'id': 'person', 'firstName': 'Pat'})
        : next.future;
  }
}

void main() {
  late MemoryStore store;
  late FakeOidc oidc;
  late FakeProfile profiles;
  late ProviderContainer container;
  setUp(() {
    store = MemoryStore();
    oidc = FakeOidc();
    profiles = FakeProfile();
    container = ProviderContainer(
      overrides: [
        sessionTokenStoreProvider.overrideWithValue(store),
        oidcClientProvider.overrideWithValue(oidc),
        profileClientProvider.overrideWithValue(profiles),
        sessionClockProvider.overrideWithValue(() => oidc.now),
      ],
    );
  });
  tearDown(() => container.dispose());
  Future<SessionController> controller() async {
    final result = container.read(sessionControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    return result;
  }

  test(
    'restoration stays loading until credentials and profile are restored',
    () async {
      store.tokens = oidc.fresh;
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.restoring,
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(sessionControllerProvider).profile?.id, 'person');
    },
  );
  test('simultaneous refresh calls rotate token once', () async {
    final session = await controller();
    await session.login();
    oidc.pending = Completer<SessionTokens>();
    final first = session.accessToken(forceRefresh: true);
    final second = session.accessToken(forceRefresh: true);
    expect(oidc.refreshes, 1);
    oidc.pending!.complete(oidc.fresh);
    expect(await first, 'fresh');
    expect(await second, 'fresh');
    expect(store.tokens?.refreshToken, 'rotated');
  });
  test('invalid grant clears secure session and expires guards', () async {
    final session = await controller();
    await session.login();
    oidc.failure = const OidcFailure(invalidGrant: true);
    await expectLater(
      session.accessToken(forceRefresh: true),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(store.tokens, null);
    expect(
      container.read(sessionControllerProvider).status,
      SessionStatus.expired,
    );
  });
  test('network refresh failure preserves persisted session', () async {
    final session = await controller();
    await session.login();
    oidc.failure = const OidcFailure();
    await expectLater(
      session.accessToken(forceRefresh: true),
      throwsA(isA<OidcFailure>()),
    );
    expect(store.tokens, isNotNull);
    expect(container.read(sessionControllerProvider).isAuthenticated, true);
  });
  test(
    'logout during refresh cannot restore session, remote failure tolerated',
    () async {
      final session = await controller();
      await session.login();
      oidc.pending = Completer<SessionTokens>();
      final refresh = session.accessToken(forceRefresh: true);
      await session.logout();
      oidc.pending!.complete(oidc.fresh);
      expect(await refresh, null);
      expect(store.tokens, null);
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.signedOut,
      );
    },
  );
  test('expired restoration refreshes before loading profile', () async {
    store.tokens = SessionTokens(
      accessToken: 'old',
      refreshToken: 'refresh',
      expiresAt: oidc.now.subtract(const Duration(minutes: 1)),
    );
    await controller();
    expect(oidc.refreshes, 1);
    expect(container.read(sessionControllerProvider).isAuthenticated, true);
    expect(store.tokens?.accessToken, 'fresh');
  });
  test(
    'network failure restoring expired token keeps credentials for retry',
    () async {
      store.tokens = SessionTokens(
        accessToken: 'old',
        refreshToken: 'refresh',
        expiresAt: oidc.now.subtract(const Duration(minutes: 1)),
      );
      oidc.failure = const OidcFailure();
      final session = await controller();
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.signedOut,
      );
      expect(store.tokens?.accessToken, 'old');
      oidc.failure = null;
      await session.restore();
      expect(container.read(sessionControllerProvider).isAuthenticated, true);
    },
  );
  test(
    'old profile401 cannot refresh or expire newly logged in identity',
    () async {
      final session = await controller();
      await session.login();
      final pending = Completer<MobileProfile>();
      profiles.pending = pending;
      final request = session.reloadProfile();
      await Future<void>.delayed(Duration.zero);
      await session.logout();
      await session.login();
      final options = RequestOptions(path: 'persons/me');
      pending.completeError(
        DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401),
        ),
      );
      await request;
      expect(oidc.refreshes, 0);
      expect(container.read(sessionControllerProvider).isAuthenticated, true);
    },
  );
  test('Delayed push cleanup cannot erase a newly logged in session', () async {
    final session = await controller();
    await session.login();
    final delayed = Completer<void>();
    container
        .read(sessionEndHooksProvider)
        .callbacks
        .add((_) => delayed.future);
    final signingOut = session.logout();
    await Future<void>.delayed(Duration.zero);
    await session.login();
    expect(store.tokens?.accessToken, 'fresh');
    delayed.complete();
    await signingOut;
    expect(store.tokens?.accessToken, 'fresh');
    expect(container.read(sessionControllerProvider).isAuthenticated, true);
  });
}
