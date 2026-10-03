import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/token_store.dart';
import '../data/oidc_client.dart';
import '../data/profile_client.dart';
import '../domain/session.dart';

final oidcClientProvider = Provider<OidcClient>(
  (ref) => AppAuthOidcClient(ref.watch(appConfigProvider)),
);
final sessionClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
final sessionTokenStoreProvider = Provider<SessionTokenStore>(
  (ref) => ref.watch(tokenStoreProvider) as SessionTokenStore,
);
final profileClientProvider = Provider<ProfileClient>((ref) {
  final url = ref.watch(appConfigProvider).apiBaseUrl.toString();
  final dio = Dio(
    BaseOptions(
      baseUrl: url.endsWith('/') ? url : '$url/',
      followRedirects: false,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return DioProfileClient(dio);
});
final sessionEndHooksProvider = Provider<SessionEndHooks>(
  (ref) => SessionEndHooks(),
);

class SessionEndHooks {
  final Set<Future<void> Function(String?)> callbacks = {};
  Future<void> run(String? token) async {
    for (final callback in callbacks.toList()) {
      try {
        await callback(token).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  SessionTokens? _tokens;
  String? _pendingLogoutIdToken;
  Future<String?>? _refreshing;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;
  int get revision => _generation;
  Future<void> _storageQueue = Future<void>.value();
  Future<void> _save(SessionTokens tokens, int generation) {
    final work = _storageQueue.then((_) async {
      if (_active(generation)) await _store.writeSession(tokens);
    });
    _storageQueue = work.catchError((Object _) {});
    return work;
  }

  Future<void> _clear() {
    final work = _storageQueue.then((_) => _store.clear());
    _storageQueue = work.catchError((Object _) {});
    return work;
  }

  SessionTokenStore get _store => ref.read(sessionTokenStoreProvider);
  DateTime get _now => ref.read(sessionClockProvider)();
  @override
  SessionState build() {
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      _timer?.cancel();
    });
    unawaited(Future<void>.microtask(restore));
    return const SessionState();
  }

  bool _active(int generation) => !_disposed && generation == _generation;
  Future<void> restore() async {
    final generation = ++_generation;
    _refreshing = null;
    _timer?.cancel();
    _tokens = null;
    state = const SessionState();
    try {
      final tokens = await _store.readSession();
      if (!_active(generation)) return;
      _tokens = tokens;
      if (tokens == null) {
        state = const SessionState(status: SessionStatus.signedOut);
        return;
      }
      final token = await accessToken();
      if (!_active(generation)) return;
      if (token == null) return;
      await reloadProfile();
      if (_active(generation)) _schedule();
    } catch (_) {
      if (_active(generation) && state.status != SessionStatus.expired) {
        state = const SessionState(
          status: SessionStatus.signedOut,
          error: 'Session temporairement indisponible. Réessayez.',
          issue: SessionIssue.connectivity,
        );
      }
    }
  }

  Future<void> login() async {
    if (state.status == SessionStatus.authenticating) return;
    final generation = ++_generation;
    _refreshing = null;
    _timer?.cancel();
    _tokens = null;
    state = const SessionState(status: SessionStatus.authenticating);
    try {
      final tokens = await ref.read(oidcClientProvider).login();
      if (!_active(generation)) return;
      await _save(tokens, generation);
      if (!_active(generation)) return;
      _tokens = tokens;
      _pendingLogoutIdToken = null;
      await reloadProfile();
      if (_active(generation)) _schedule();
    } catch (e) {
      if (_active(generation)) {
        state = SessionState(
          status: SessionStatus.signedOut,
          error: e is OidcFailure && e.cancelled
              ? null
              : 'Connexion impossible. Réessayez.',
          issue: e is OidcFailure && e.cancelled
              ? null
              : SessionIssue.authentication,
        );
      }
    }
  }

  Future<String?> accessToken({bool forceRefresh = false}) {
    final current = _tokens;
    if (current == null) return Future.value(null);
    if (!forceRefresh &&
        current.expiresAt.isAfter(_now.add(const Duration(seconds: 60)))) {
      return Future.value(current.accessToken);
    }
    if (_refreshing != null) return _refreshing!;
    final future = _refresh();
    _refreshing = future;
    unawaited(
      future.then<void>(
        (_) {
          if (identical(_refreshing, future)) _refreshing = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_refreshing, future)) _refreshing = null;
        },
      ),
    );
    return future;
  }

  Future<String?> _refresh() async {
    final generation = _generation;
    final previous = _tokens!;
    if (previous.refreshToken == null) {
      await expire();
      throw SessionExpiredException();
    }
    try {
      final tokens = await ref.read(oidcClientProvider).refresh(previous);
      if (!_active(generation)) return null;
      await _save(tokens, generation);
      if (!_active(generation)) return null;
      _tokens = tokens;
      _schedule();
      return tokens.accessToken;
    } catch (e) {
      if (!_active(generation)) return null;
      if (e is OidcFailure && e.invalidGrant) {
        await expire();
        throw SessionExpiredException();
      }
      state = SessionState(
        status: state.status,
        profile: state.profile,
        error: 'Renouvellement temporairement indisponible. Réessayez.',
        issue: SessionIssue.connectivity,
      );
      rethrow;
    }
  }

  Future<void> reloadProfile() async {
    final generation = _generation;
    try {
      var token = await accessToken();
      if (token == null || !_active(generation)) return;
      MobileProfile profile;
      try {
        profile = await ref.read(profileClientProvider).fetch(token);
      } on DioException catch (e) {
        if (!_active(generation)) return;
        if (e.response?.statusCode != 401) rethrow;
        token = await accessToken(forceRefresh: true);
        if (token == null || !_active(generation)) return;
        try {
          profile = await ref.read(profileClientProvider).fetch(token);
        } on DioException catch (retry) {
          if (!_active(generation)) return;
          if (retry.response?.statusCode == 401) await expire();
          rethrow;
        }
      }
      if (_active(generation)) {
        state = SessionState(
          status: SessionStatus.authenticated,
          profile: profile,
        );
      }
    } catch (error) {
      if (_active(generation)) {
        state = SessionState(
          status: SessionStatus.authenticated,
          profile: state.profile,
          issue: error is DioException && error.response?.statusCode == 404
              ? SessionIssue.profileUnlinked
              : SessionIssue.connectivity,
          error: error is DioException && error.response?.statusCode == 404
              ? 'Votre identité HEALTH’YS doit être associée à votre compte.'
              : 'Profil temporairement indisponible. Réessayez.',
        );
      }
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (_tokens == null || _disposed) return;
    final delay =
        _tokens!.expiresAt.difference(_now) - const Duration(seconds: 60);
    _timer = Timer(
      delay.isNegative ? const Duration(seconds: 1) : delay,
      () async {
        try {
          await accessToken(forceRefresh: true);
        } catch (_) {
          /* Next request or retry restores connectivity. */
        }
      },
    );
  }

  Future<void> expire() async {
    final oldToken = _tokens?.accessToken;
    final cleanup = ref.read(sessionEndHooksProvider);
    final generation = ++_generation;
    _refreshing = null;
    _timer?.cancel();
    _tokens = null;
    state = const SessionState(status: SessionStatus.expired);
    try {
      final clearing = _clear();
      await Future.wait([clearing, cleanup.run(oldToken)]);
    } catch (_) {
      if (!_active(generation)) return;
      state = const SessionState(
        status: SessionStatus.expired,
        error:
            'Session expirée. Impossible de supprimer les données sécurisées.',
        logoutFailed: true,
        issue: SessionIssue.storage,
      );
    }
  }

  Future<void> logout() async {
    final oldToken = _tokens?.accessToken;
    final cleanup = ref.read(sessionEndHooksProvider);
    final idToken = _tokens?.idToken ?? _pendingLogoutIdToken;
    _pendingLogoutIdToken = idToken;
    final generation = ++_generation;
    _refreshing = null;
    _timer?.cancel();
    _tokens = null;
    state = const SessionState(status: SessionStatus.signedOut);
    try {
      final clearing = _clear();
      await Future.wait([clearing, cleanup.run(oldToken)]);
    } catch (_) {
      if (!_active(generation)) return;
      state = const SessionState(
        status: SessionStatus.signedOut,
        error:
            'Impossible de supprimer la session sécurisée. Réessayez la déconnexion.',
        logoutFailed: true,
        issue: SessionIssue.storage,
      );
    }
    try {
      await ref.read(oidcClientProvider).logout(idToken);
      if (_active(generation)) _pendingLogoutIdToken = null;
    } catch (_) {
      if (_active(generation) && !state.logoutFailed) {
        state = const SessionState(
          status: SessionStatus.signedOut,
          error:
              'Session mobile fermée. La déconnexion Keycloak est temporairement indisponible.',
          issue: SessionIssue.remoteLogout,
        );
      }
    }
  }
}
