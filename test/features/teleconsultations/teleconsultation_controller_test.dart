import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/config/app_config.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/teleconsultations/application/teleconsultation_providers.dart';
import 'package:healthysv2/features/teleconsultations/data/teleconsultation_media.dart';
import 'package:healthysv2/features/teleconsultations/data/teleconsultation_repository.dart';
import 'package:healthysv2/features/teleconsultations/domain/teleconsultation.dart';

class TestSession extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'person-1'}),
  );
  void signOut() => state = const SessionState(status: SessionStatus.signedOut);
  void switchUser() => state = const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'person-2'}),
  );
}

class Repository implements TeleconsultationRepository {
  VideoSession session = const VideoSession(
    id: 'session',
    sessionNumber: 'V-1',
    status: 'ACTIVE',
    canJoin: true,
  );
  int tokens = 0, leaves = 0, entries = 0;
  String server = 'wss://livekit.test';
  Completer<VideoSessionToken>? pendingToken;
  Object? detailError;
  @override
  Future<VideoSessionPage> list(
    VideoSessionQuery query, {
    CancelToken? cancelToken,
  }) async => VideoSessionPage(
    content: [session],
    totalElements: 1,
    totalPages: 1,
    number: query.page,
    size: query.size,
  );
  @override
  Future<VideoSession> detail(String id, {CancelToken? cancelToken}) async {
    if (detailError != null) {
      throw detailError!;
    }
    return session;
  }

  @override
  Future<void> enterWaitingRoom(String id, {CancelToken? cancelToken}) async {
    entries++;
  }

  @override
  Future<VideoSessionToken> token(String id, {CancelToken? cancelToken}) async {
    tokens++;
    return pendingToken == null
        ? VideoSessionToken(
            serverUrl: server,
            token: 'secret',
            roomName: 'room',
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          )
        : pendingToken!.future;
  }

  @override
  Future<void> leave(String id, {CancelToken? cancelToken}) async {
    leaves++;
  }
}

class Permissions implements TeleconsultationPermissions {
  bool allowed = true;
  int requests = 0;
  Completer<bool>? pending;
  @override
  Future<bool> request({required bool camera, required bool microphone}) async {
    requests++;
    return pending == null ? allowed : pending!.future;
  }

  @override
  Future<void> openSettings() async {}
}

class Media implements TeleconsultationMedia {
  final controller = StreamController<MediaConnection>.broadcast();
  int connections = 0, closes = 0;
  bool camera = false, microphone = false;
  Completer<void>? pendingConnect;
  Completer<void>? pendingClose;
  @override
  Stream<MediaConnection> get events => controller.stream;
  @override
  Future<void> connect(VideoSessionToken token) async {
    connections++;
    if (pendingConnect != null) {
      await pendingConnect!.future;
    }
  }

  @override
  Future<void> close() async {
    closes++;
    if (pendingClose != null) {
      await pendingClose!.future;
    }
    camera = false;
    microphone = false;
  }

  @override
  Future<void> setCamera(bool enabled) async {
    camera = enabled;
  }

  @override
  Future<void> setMicrophone(bool enabled) async {
    microphone = enabled;
  }

  @override
  Future<void> switchCamera() async {}
  @override
  bool get hasRemoteVideo => false;
  @override
  Widget videoView({required bool local}) => const SizedBox();
}

void main() {
  late ProviderContainer container;
  late Repository repository;
  late Permissions permissions;
  late Media media;
  late TestSession session;
  late TeleconsultationController call;
  late ProviderSubscription<CallState> subscription;
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() async {
    repository = Repository();
    permissions = Permissions();
    media = Media();
    session = TestSession();
    container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(() => session),
        appConfigProvider.overrideWithValue(
          AppConfig(
            environment: AppEnvironment.prod,
            apiBaseUrl: Uri.parse('https://api.test/api/v1'),
          ),
        ),
        teleconsultationRepositoryProvider.overrideWithValue(repository),
        teleconsultationPermissionsProvider.overrideWithValue(permissions),
        teleconsultationMediaFactoryProvider.overrideWithValue(() => media),
        teleconsultationPollIntervalProvider.overrideWithValue(null),
      ],
    );
    subscription = container.listen(
      teleconsultationControllerProvider('session'),
      (_, _) {},
    );
    call = container.read(
      teleconsultationControllerProvider('session').notifier,
    );
    await settle();
  });
  tearDown(() async {
    subscription.close();
    container.dispose();
    await settle();
    await media.controller.close();
  });
  CallState current() =>
      container.read(teleconsultationControllerProvider('session'));
  test('waiting room never acquires media or token', () async {
    await call.enterWaitingRoom();
    expect(repository.entries, 1);
    expect(repository.tokens, 0);
    expect(media.connections, 0);
    expect(permissions.requests, 0);
  });
  test('join defaults camera and microphone off', () async {
    await call.join();
    expect(current().phase, CallPhase.connected);
    expect(media.camera, false);
    expect(media.microphone, false);
  });
  test(
    'explicit camera and microphone consent publishes requested media',
    () async {
      await call.join(camera: true, microphone: true);
      expect(media.camera, true);
      expect(media.microphone, true);
      expect(current().cameraEnabled, true);
    },
  );
  test('permission refusal obtains no token and opens no media', () async {
    permissions.allowed = false;
    await call.join(camera: true);
    expect(current().phase, CallPhase.permissionDenied);
    expect(repository.tokens, 0);
    expect(media.connections, 0);
  });
  test('unadmitted patient cannot obtain a token', () async {
    repository.session = const VideoSession(
      id: 'session',
      sessionNumber: 'V',
      status: 'ACTIVE',
    );
    await call.join();
    expect(repository.tokens, 0);
    expect(current().phase, CallPhase.waiting);
  });
  test('ended session cannot join', () async {
    repository.session = const VideoSession(
      id: 'session',
      sessionNumber: 'V',
      status: 'COMPLETED',
      canJoin: true,
    );
    await call.join();
    expect(repository.tokens, 0);
    expect(current().phase, CallPhase.ended);
  });
  test('production rejects insecure LiveKit endpoint', () async {
    repository.server = 'ws://livekit.test';
    await call.join();
    expect(current().phase, CallPhase.failed);
    expect(media.connections, 0);
  });
  test('credential-bearing endpoint is rejected', () async {
    repository.server = 'wss://secret@livekit.test';
    await call.join();
    expect(media.connections, 0);
    expect(current().error?.toString(), isNot(contains('secret')));
  });
  test(
    'background interruption immediately clears renderer and media',
    () async {
      await call.join(camera: true, microphone: true);
      await call.interrupt();
      expect(current().phase, CallPhase.interrupted);
      expect(current().media, null);
      expect(media.camera, false);
      expect(media.microphone, false);
      expect(repository.leaves, 0);
    },
  );
  test('resume refresh never rejoins without deliberate user action', () async {
    await call.join();
    await call.interrupt();
    call.setVisible(true);
    await settle();
    expect(media.connections, 1);
    expect(current().phase, CallPhase.interrupted);
    await call.join();
    expect(repository.tokens, 2);
  });
  test('provider disposal closes media', () async {
    await call.join(camera: true);
    subscription.close();
    await container.pump();
    await settle();
    expect(media.closes, greaterThan(0));
  });
  test('sign out closes media and discards session data', () async {
    await call.join(camera: true);
    session.signOut();
    await container.pump();
    await settle();
    expect(media.camera, false);
    expect(current().session, null);
  });
  test('account switch closes old media', () async {
    await call.join(microphone: true);
    session.switchUser();
    await container.pump();
    await settle();
    expect(media.microphone, false);
    expect(media.closes, greaterThan(0));
  });
  test('late token after interruption never connects', () async {
    repository.pendingToken = Completer();
    final joining = call.join(camera: true);
    await settle();
    await call.interrupt();
    repository.pendingToken!.complete(
      VideoSessionToken(
        serverUrl: 'wss://livekit.test',
        token: 'secret',
        roomName: 'room',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      ),
    );
    await joining;
    expect(media.connections, 0);
    expect(current().phase, CallPhase.interrupted);
  });
  test('late connection after interruption never publishes', () async {
    media.pendingConnect = Completer();
    final joining = call.join(camera: true, microphone: true);
    await settle();
    await call.interrupt();
    media.pendingConnect!.complete();
    await joining;
    expect(media.camera, false);
    expect(media.microphone, false);
    expect(current().media, null);
  });
  test('inactive permission dialog does not cancel first-time join', () async {
    permissions.pending = Completer();
    final joining = call.join(camera: true);
    await settle();
    await call.interrupt(inactive: true);
    permissions.pending!.complete(true);
    await joining;
    expect(current().phase, CallPhase.connected);
    expect(media.camera, true);
  });
  test('completed server status stops active media', () async {
    await call.join(camera: true, microphone: true);
    repository.session = const VideoSession(
      id: 'session',
      sessionNumber: 'V',
      status: 'COMPLETED',
    );
    await call.refresh();
    expect(current().phase, CallPhase.ended);
    expect(media.camera, false);
    expect(media.microphone, false);
  });
  test('patient leave never invokes room end and media stops', () async {
    await call.join(camera: true);
    await call.leave();
    expect(repository.leaves, 1);
    expect(media.camera, false);
    expect(current().phase, CallPhase.ended);
  });
  test('network disconnect requires explicit fresh rejoin', () async {
    await call.join();
    media.controller.add(MediaConnection.disconnected);
    await settle();
    expect(current().phase, CallPhase.interrupted);
    expect(current().media, null);
    expect(repository.tokens, 1);
  });
  test('rejoin waits for interrupted capture to finish closing', () async {
    await call.join(camera: true);
    media.pendingClose = Completer();
    final stopping = call.interrupt();
    await settle();
    final rejoining = call.join(camera: true);
    await settle();
    expect(media.connections, 1);
    media.pendingClose!.complete();
    await stopping;
    await rejoining;
    expect(media.connections, 2);
    expect(current().phase, CallPhase.connected);
  });
  test('stale server completion cannot overwrite the next account', () async {
    await call.join(camera: true);
    media.pendingClose = Completer();
    repository.session = const VideoSession(
      id: 'session',
      sessionNumber: 'old',
      status: 'COMPLETED',
    );
    final checking = call.refresh();
    await settle();
    repository.session = const VideoSession(
      id: 'session',
      sessionNumber: 'new',
      status: 'ACTIVE',
    );
    session.switchUser();
    await container.pump();
    await settle();
    media.pendingClose!.complete();
    await checking;
    await settle();
    expect(current().session?.sessionNumber, 'new');
    expect(current().phase, isNot(CallPhase.ended));
  });
  test(
    'revoked access stops capture before showing forbidden status',
    () async {
      await call.join(camera: true, microphone: true);
      repository.detailError = const AppException(
        kind: AppErrorKind.forbidden,
        message: 'Accès refusé',
        statusCode: 403,
      );
      await call.refresh();
      expect(current().phase, CallPhase.interrupted);
      expect(media.camera, false);
      expect(media.microphone, false);
      expect(current().error?.statusCode, 403);
    },
  );
  test('active session losing admission stops both media tracks', () async {
    await call.join(camera: true, microphone: true);
    repository.session = const VideoSession(
      id: 'session',
      sessionNumber: 'V-1',
      status: 'ACTIVE',
      canJoin: false,
    );
    await call.refresh();
    expect(current().phase, CallPhase.interrupted);
    expect(current().session?.canJoin, false);
    expect(current().media, null);
    expect(media.camera, false);
    expect(media.microphone, false);
    expect(repository.leaves, 0);
  });
}
