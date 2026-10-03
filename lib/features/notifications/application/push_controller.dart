import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/config/app_config.dart';
import '../../auth/application/session_controller.dart';
import '../data/notification_repository.dart';
import '../data/push_client.dart';
import '../domain/notifications.dart';
import 'notification_providers.dart';

enum PushStatus {
  disabled,
  idle,
  enabled,
  denied,
  unavailable,
  registrationFailed,
}

class PushState {
  const PushState({
    this.status = PushStatus.disabled,
    this.pendingNotificationId,
    this.foregroundRevision = 0,
  });
  final PushStatus status;
  final String? pendingNotificationId;
  final int foregroundRevision;
}

abstract interface class PushInstallationStore {
  Future<String> installation(String namespace);
  Future<void> remove(String namespace);
}

class SecurePushInstallationStore implements PushInstallationStore {
  const SecurePushInstallationStore();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String> installation(String namespace) async {
    final key = 'healthys.push.installation.$namespace';
    final existing = await _storage.read(key: key);
    if (notificationUuid(existing)) {
      return existing!;
    }
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _storage.write(key: key, value: id);
    return id;
  }

  @override
  Future<void> remove(String namespace) =>
      _storage.delete(key: 'healthys.push.installation.$namespace');
}

final pushInstallationStoreProvider = Provider<PushInstallationStore>(
  (ref) => const SecurePushInstallationStore(),
);
final pushControllerProvider = NotifierProvider<PushController, PushState>(
  PushController.new,
);

class PushController extends Notifier<PushState> {
  PushClient? _client;
  String? _installationId, _namespace;
  int _generation = 0;
  bool _ready = false, _disposed = false;
  Future<void> _queue = Future.value();
  final List<StreamSubscription<String>> _subscriptions = [];
  @override
  PushState build() {
    final hooks = ref.read(sessionEndHooksProvider);
    hooks.callbacks.add(_cleanup);
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      hooks.callbacks.remove(_cleanup);
      for (final stream in _subscriptions) {
        unawaited(stream.cancel());
      }
    });
    ref.listen(sessionControllerProvider, (previous, next) {
      if (previous?.profile?.id != next.profile?.id ||
          previous?.status != next.status) {
        _generation++;
      }
      if (next.isAuthenticated && next.profile?.id != null) {
        unawaited(_restore());
      } else if (previous?.isAuthenticated == true) {
        state = PushState(
          status: _ready ? PushStatus.idle : PushStatus.disabled,
        );
      }
    });
    unawaited(Future<void>.microtask(_initialize));
    return const PushState();
  }

  bool _current(int generation) =>
      !_disposed &&
      ref.mounted &&
      generation == _generation &&
      ref.read(sessionControllerProvider).isAuthenticated;
  Future<void> _initialize() async {
    _client = ref.read(pushClientProvider);
    try {
      _ready = await _client!.initialize();
      if (_disposed) {
        return;
      }
      state = PushState(status: _ready ? PushStatus.idle : PushStatus.disabled);
      if (!_ready) {
        return;
      }
      _subscriptions.add(_client!.openedIds.listen(_opened));
      _subscriptions.add(
        _client!.foregroundIds.listen((id) => unawaited(_foreground(id))),
      );
      _subscriptions.add(
        _client!.tokenChanges.listen((token) {
          if (state.status == PushStatus.enabled) {
            unawaited(_register(token));
          }
        }),
      );
      final initial = await _client!.initialNotificationId();
      if (initial != null) {
        _opened(initial);
      }
      await _restore();
    } catch (_) {
      if (!_disposed) {
        state = const PushState(status: PushStatus.unavailable);
      }
    }
  }

  Future<void> _foreground(String id) async {
    final generation = _generation;
    if (!notificationUuid(id) || !_current(generation)) {
      return;
    }
    try {
      final preferences = await ref
          .read(notificationRepositoryProvider)
          .preferences();
      if (!_current(generation)) {
        return;
      }
      ref.invalidate(notificationsProvider);
      ref.invalidate(notificationUnreadCountProvider);
      if (!preferences.inAppEnabled) {
        return;
      }
      state = PushState(
        status: state.status,
        pendingNotificationId: state.pendingNotificationId,
        foregroundRevision: state.foregroundRevision + 1,
      );
    } catch (_) {
      /* A failed preference lookup must not display a banner. */
    }
  }

  void _opened(String id) {
    if (_disposed || !notificationUuid(id)) {
      return;
    }
    state = PushState(
      status: state.status,
      pendingNotificationId: id,
      foregroundRevision: state.foregroundRevision,
    );
  }

  void consumePending([String? expectedId]) {
    if (expectedId != null && state.pendingNotificationId != expectedId) {
      return;
    }
    state = PushState(
      status: state.status,
      foregroundRevision: state.foregroundRevision,
    );
  }

  Future<void> _restore() async {
    if (!_ready || !ref.read(sessionControllerProvider).isAuthenticated) {
      return;
    }
    final generation = _generation;
    try {
      final preferences = await ref
          .read(notificationRepositoryProvider)
          .preferences();
      if (!_current(generation)) {
        return;
      }
      if (preferences.pushEnabled) {
        await _queue;
        if (!_current(generation)) {
          return;
        }
        final token = await _client!.token();
        if (!_current(generation)) {
          return;
        }
        if (token == null) {
          state = PushState(
            status: PushStatus.registrationFailed,
            pendingNotificationId: state.pendingNotificationId,
          );
          return;
        }
        await _register(token);
      }
    } catch (_) {
      if (_current(generation)) {
        state = PushState(
          status: PushStatus.unavailable,
          pendingNotificationId: state.pendingNotificationId,
        );
      }
    }
  }

  Future<void> resume() => _restore();
  Future<void> enable() async {
    if (!_ready || !ref.read(sessionControllerProvider).isAuthenticated) {
      return;
    }
    final generation = _generation;
    try {
      final permission = await _client!.requestPermission();
      if (!_current(generation)) {
        return;
      }
      if (!permission) {
        state = PushState(
          status: PushStatus.denied,
          pendingNotificationId: state.pendingNotificationId,
        );
        return;
      }
      final preferences = await ref
          .read(notificationRepositoryProvider)
          .preferences();
      if (!_current(generation)) {
        return;
      }
      await ref
          .read(notificationRepositoryProvider)
          .savePreferences(preferences.copyWith(pushEnabled: true));
      if (!_current(generation)) {
        return;
      }
      ref.invalidate(notificationPreferencesProvider);
      await _queue;
      if (!_current(generation)) {
        return;
      }
      final token = await _client!.token();
      if (!_current(generation)) {
        return;
      }
      if (token == null) {
        state = PushState(
          status: PushStatus.registrationFailed,
          pendingNotificationId: state.pendingNotificationId,
        );
        return;
      }
      await _register(token);
    } catch (_) {
      if (_current(generation)) {
        state = PushState(
          status: PushStatus.unavailable,
          pendingNotificationId: state.pendingNotificationId,
        );
      }
    }
  }

  Future<void> _register(String token) {
    final generation = _generation;
    final work = _queue.then((_) async {
      if (!_current(generation)) {
        return;
      }
      final person = ref.read(sessionControllerProvider).profile?.id;
      if (person == null) {
        return;
      }
      final namespace = '${ref.read(appConfigProvider).apiBaseUrl}|$person';
      final installation = await ref
          .read(pushInstallationStoreProvider)
          .installation(namespace);
      if (!_current(generation)) {
        return;
      }
      _installationId = installation;
      _namespace = namespace;
      final repository = ref.read(notificationRepositoryProvider);
      final revocations = ref.read(pushRevocationStoreProvider);
      await _revokePending(repository, revocations, exceptId: installation);
      if (!_current(generation)) {
        return;
      }
      final previousCapabilities = await revocations.load();
      final capability =
          previousCapabilities[installation] ??
          base64Url
              .encode(List.generate(32, (_) => Random.secure().nextInt(256)))
              .replaceAll('=', '');
      await revocations.save(installation, capability);
      if (!_current(generation)) {
        return;
      }
      await repository.registerDevice(
        installation,
        token,
        defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID',
        capability,
      );
      if (!_current(generation)) {
        return;
      }
      state = PushState(
        status: PushStatus.enabled,
        pendingNotificationId: state.pendingNotificationId,
        foregroundRevision: state.foregroundRevision,
      );
    });
    _queue = work.catchError((Object _) {
      if (_current(generation)) {
        state = PushState(
          status: PushStatus.registrationFailed,
          pendingNotificationId: state.pendingNotificationId,
        );
      }
    });
    return _queue;
  }

  Future<void> disable() async {
    final generation = _generation;
    try {
      final preferences = await ref
          .read(notificationRepositoryProvider)
          .preferences();
      if (!_current(generation)) {
        return;
      }
      await ref
          .read(notificationRepositoryProvider)
          .savePreferences(preferences.copyWith(pushEnabled: false));
      if (!_current(generation)) {
        return;
      }
      ref.invalidate(notificationPreferencesProvider);
      await _cleanup(
        await ref.read(sessionControllerProvider.notifier).accessToken(),
      );
      if (_current(generation)) {
        state = const PushState(status: PushStatus.idle);
      }
    } catch (_) {
      if (_current(generation)) {
        state = PushState(
          status: PushStatus.unavailable,
          pendingNotificationId: state.pendingNotificationId,
        );
      }
    }
  }

  Future<void> _cleanup(String? accessToken) {
    final repository = ref.read(notificationRepositoryProvider);
    final revocations = ref.read(pushRevocationStoreProvider);
    final installations = ref.read(pushInstallationStoreProvider);
    final client = _client;
    final work = _queue.then((_) async {
      final id = _installationId, namespace = _namespace;
      _installationId = null;
      _namespace = null;
      // Delete the local FCM token even when the old access token has expired.
      try {
        await client?.deleteToken().timeout(const Duration(seconds: 2));
      } catch (_) {}
      try {
        await _revokePending(repository, revocations);
      } catch (_) {}
      if (id != null && accessToken != null) {
        try {
          await repository
              .unregisterDevice(id, accessToken: accessToken)
              .timeout(const Duration(seconds: 2));
        } catch (_) {}
      }
      if (namespace != null) {
        try {
          await installations.remove(namespace);
        } catch (_) {}
      }
    });
    _queue = work.catchError((Object _) {});
    return _queue;
  }
}

abstract interface class PushRevocationStore {
  Future<Map<String, String>> load();
  Future<void> save(String installationId, String revocationToken);
  Future<void> remove(String installationId);
}

class SecurePushRevocationStore implements PushRevocationStore {
  const SecurePushRevocationStore(this.namespace);
  final String namespace;
  static const _storage = FlutterSecureStorage();
  String get _key => 'healthys.push.pending-revocations.v1.$namespace';
  @override
  Future<Map<String, String>> load() async {
    final value = await _storage.read(key: _key);
    if (value == null) {
      return {};
    }
    return (jsonDecode(value) as Map<String, dynamic>).cast<String, String>();
  }

  @override
  Future<void> save(String installationId, String revocationToken) async {
    final pending = await load();
    pending[installationId] = revocationToken;
    await _storage.write(key: _key, value: jsonEncode(pending));
  }

  @override
  Future<void> remove(String installationId) async {
    final pending = await load();
    pending.remove(installationId);
    await _storage.write(key: _key, value: jsonEncode(pending));
  }
}

final pushRevocationStoreProvider = Provider<PushRevocationStore>(
  (ref) => SecurePushRevocationStore(
    base64Url.encode(
      utf8.encode(ref.watch(appConfigProvider).apiBaseUrl.toString()),
    ),
  ),
);
Future<void> _revokePending(
  NotificationRepository repository,
  PushRevocationStore store, {
  String? exceptId,
}) async {
  final pending = await store.load();
  for (final entry in pending.entries) {
    if (entry.key == exceptId) {
      continue;
    }
    await repository
        .revokeDevice(entry.key, entry.value)
        .timeout(const Duration(seconds: 2));
    await store.remove(entry.key);
  }
}
