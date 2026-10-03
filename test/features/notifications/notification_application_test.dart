import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/config/app_config.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/notifications/application/notification_providers.dart';
import 'package:healthysv2/features/notifications/application/push_controller.dart';
import 'package:healthysv2/features/notifications/data/notification_repository.dart';
import 'package:healthysv2/features/notifications/data/push_client.dart';
import 'package:healthysv2/features/notifications/domain/notifications.dart';

const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
Map<String, dynamic> json({String resource = 'CONVERSATION'}) => {
  'id': id,
  'type': 'MESSAGE',
  'title': null,
  'body': 'Hello',
  'resourceType': resource,
  'resourceId': id,
  'actionUrl': 'https://evil.example',
  'priority': 'NORMAL',
  'createdAt': '2026-10-03T00:00:00Z',
  'status': 'ACTIVE',
  'read': false,
};
const preferences = NotificationPreferences(
  inAppEnabled: true,
  emailEnabled: true,
  smsEnabled: false,
  pushEnabled: false,
  quietHoursStart: '22:00:00',
  quietHoursEnd: '06:00:00',
  locale: 'fr',
);

class Session extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'person'}),
  );
  void signOut() => state = const SessionState(status: SessionStatus.signedOut);
  void change() => state = const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'other'}),
  );
}

class Repository implements NotificationRepository {
  NotificationPreferences prefs = preferences;
  Completer<HealthysNotification>? pendingDetail;
  int registrations = 0, revocations = 0, reads = 0;
  bool failRegister = false, failRevoke = false;
  final capabilities = <String>[];
  final store = Revocations();
  @override
  Future<NotificationPreferences> preferences({
    CancelToken? cancelToken,
  }) async => prefs;
  @override
  Future<NotificationPreferences> savePreferences(
    NotificationPreferences preferences, {
    CancelToken? cancelToken,
  }) async => prefs = preferences;
  @override
  Future<String> registerDevice(
    String installationId,
    String token,
    String platform,
    String revocationToken, {
    CancelToken? cancelToken,
  }) async {
    expect(store.values[installationId], revocationToken);
    registrations++;
    capabilities.add(revocationToken);
    if (failRegister) {
      throw StateError('offline');
    }
    return revocationToken;
  }

  @override
  Future<void> revokeDevice(
    String installationId,
    String revocationToken,
  ) async {
    revocations++;
    if (failRevoke) {
      throw StateError('offline');
    }
  }

  @override
  Future<void> unregisterDevice(
    String installationId, {
    String? accessToken,
  }) async {}
  @override
  Future<HealthysNotification> detail(String id, {CancelToken? cancelToken}) =>
      pendingDetail?.future ??
      Future.value(HealthysNotification.fromJson(json()));
  @override
  Future<HealthysNotification> markRead(
    String id, {
    CancelToken? cancelToken,
  }) async {
    reads++;
    return HealthysNotification.fromJson(json());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Client implements PushClient {
  bool permission = true, available = true;
  int requests = 0, deletes = 0;
  String? currentToken = 'token';
  final changes = StreamController<String>.broadcast();
  final opened = StreamController<String>.broadcast();
  final foreground = StreamController<String>.broadcast();
  @override
  Future<bool> initialize() async => available;
  @override
  Future<bool> requestPermission() async {
    requests++;
    return permission;
  }

  @override
  Future<String?> token() async => currentToken;
  @override
  Future<void> deleteToken() async {
    deletes++;
  }

  @override
  Stream<String> get tokenChanges => changes.stream;
  @override
  Stream<String> get openedIds => opened.stream;
  @override
  Stream<String> get foregroundIds => foreground.stream;
  @override
  Future<String?> initialNotificationId() async => null;
  Future<void> close() async {
    await changes.close();
    await opened.close();
    await foreground.close();
  }
}

class Installations implements PushInstallationStore {
  @override
  Future<String> installation(String namespace) async => id;
  @override
  Future<void> remove(String namespace) async {}
}

class Revocations implements PushRevocationStore {
  final values = <String, String>{};
  @override
  Future<Map<String, String>> load() async => Map.of(values);
  @override
  Future<void> save(String id, String token) async {
    values[id] = token;
  }

  @override
  Future<void> remove(String id) async {
    values.remove(id);
  }
}

Future<void> flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('Only UUID notification ID crosses untrusted push boundary', () {
    expect(
      pushNotificationId({'notificationId': id, 'url': 'https://evil'}),
      id,
    );
    expect(pushNotificationId({'notificationId': '../../patient'}), null);
    expect(pushNotificationId({'url': '/messages/$id'}), null);
  });
  test('Authenticated notification routes only allowlisted resource types', () {
    expect(
      notificationDestination(HealthysNotification.fromJson(json())),
      '/messages/$id',
    );
    expect(
      notificationDestination(
        HealthysNotification.fromJson(json(resource: 'EXTERNAL')),
      ),
      '/notifications',
    );
  });
  test('Preferences preserve non-push channels and UTC quiet hours', () {
    final updated = preferences.copyWith(pushEnabled: true);
    expect(updated.toJson(), {...preferences.toJson(), 'pushEnabled': true});
  });
  test('Timestamp timezone required', () {
    expect(
      () => HealthysNotification.fromJson({
        ...json(),
        'createdAt': '2026-10-03T00:00:00',
      }),
      throwsFormatException,
    );
  });
  group('Push session lifecycle', () {
    late ProviderContainer container;
    late Repository repository;
    late Client client;
    setUp(() async {
      repository = Repository();
      client = Client();
      container = ProviderContainer(
        overrides: [
          sessionControllerProvider.overrideWith(Session.new),
          notificationRepositoryProvider.overrideWithValue(repository),
          pushClientProvider.overrideWithValue(client),
          pushInstallationStoreProvider.overrideWithValue(Installations()),
          pushRevocationStoreProvider.overrideWithValue(repository.store),
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(
              environment: 'dev',
              apiBaseUrl: 'http://localhost:8080/api/v1',
            ),
          ),
        ],
      );
      container.read(pushControllerProvider);
      await flush();
    });
    tearDown(() async {
      container.dispose();
      await client.close();
    });
    test('Startup does not request OS permission or register token', () {
      expect(client.requests, 0);
      expect(repository.registrations, 0);
      expect(container.read(pushControllerProvider).status, PushStatus.idle);
    });
    test(
      'Explicit opt-in registers persisted revocation secret preserving preferences',
      () async {
        await container.read(pushControllerProvider.notifier).enable();
        expect(repository.registrations, 1);
        expect(repository.capabilities.single.length, 43);
        expect(repository.prefs.emailEnabled, true);
        expect(repository.prefs.quietHoursStart, '22:00:00');
        expect(
          container.read(pushControllerProvider).status,
          PushStatus.enabled,
        );
      },
    );
    test(
      'OS denied permission never registers or enables preference',
      () async {
        client.permission = false;
        await container.read(pushControllerProvider.notifier).enable();
        expect(repository.registrations, 0);
        expect(repository.prefs.pushEnabled, false);
        expect(
          container.read(pushControllerProvider).status,
          PushStatus.denied,
        );
      },
    );
    test('Token rotation preserves capability and active device', () async {
      await container.read(pushControllerProvider.notifier).enable();
      client.changes.add('rotated');
      await flush();
      expect(repository.registrations, 2);
      expect(repository.revocations, 0);
      expect(repository.capabilities[0], repository.capabilities[1]);
    });
    test('Lost registration response retains capability for retry', () async {
      repository.failRegister = true;
      await container.read(pushControllerProvider.notifier).enable();
      expect(repository.store.values, isNotEmpty);
      expect(
        container.read(pushControllerProvider).status,
        PushStatus.registrationFailed,
      );
      repository.failRegister = false;
      await container.read(pushControllerProvider.notifier).resume();
      expect(repository.capabilities[0], repository.capabilities[1]);
    });
    test(
      'Signed out foreground push exposes no notification revision',
      () async {
        (container.read(sessionControllerProvider.notifier) as Session)
            .signOut();
        client.foreground.add(id);
        await flush();
        expect(container.read(pushControllerProvider).foregroundRevision, 0);
      },
    );
    test('Expiry cleanup revokes without JWT and deletes FCM token', () async {
      await container.read(pushControllerProvider.notifier).enable();
      await container.read(sessionEndHooksProvider).run(null);
      expect(client.deletes, 1);
      expect(repository.revocations, 1);
      expect(repository.store.values, isEmpty);
    });
    test('Offline cleanup retains capability', () async {
      await container.read(pushControllerProvider.notifier).enable();
      repository.failRevoke = true;
      await container.read(sessionEndHooksProvider).run(null);
      expect(repository.store.values, isNotEmpty);
    });
    test(
      'Account change cancels notification navigation and read mutation',
      () async {
        repository.pendingDetail = Completer();
        final action = container.read(notificationActionsProvider).open(id);
        final checked = expectLater(action, throwsA(isA<Object>()));
        (container.read(sessionControllerProvider.notifier) as Session)
            .change();
        repository.pendingDetail!.complete(
          HealthysNotification.fromJson(json()),
        );
        await checked;
        expect(repository.reads, 0);
      },
    );
  });
}
