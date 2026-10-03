import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:healthysv2/app/router/app_router.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/teleconsultations/application/teleconsultation_providers.dart';
import 'package:healthysv2/features/teleconsultations/domain/teleconsultation.dart';
import 'package:healthysv2/features/teleconsultations/presentation/teleconsultation_room_page.dart';
import 'package:healthysv2/features/teleconsultations/presentation/teleconsultations_page.dart';

const roomId = '00000000-0000-0000-0000-000000001811';
const patientPersonId = '00000000-0000-0000-0000-000000001812';

VideoSession room({String status = 'ACTIVE', String admission = 'WAITING'}) =>
    VideoSession(
      id: roomId,
      sessionNumber: 'VIDEO-1811',
      status: status,
      canJoin: status == 'ACTIVE' && admission == 'ADMITTED',
      scheduledStart: DateTime.utc(2026, 10, 3, 12),
      participants: const [
        VideoParticipant(personId: patientPersonId, role: 'PATIENT'),
        VideoParticipant(
          personId: 'professional',
          role: 'PROFESSIONAL',
          displayName: 'Dr Healthys',
        ),
      ],
      waitingRoom: [
        WaitingRoomEntry(patientId: 'patient-record', status: admission),
      ],
    );

class VideoSessionIdentity extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': patientPersonId}),
  );
  void signOut() => state = const SessionState(status: SessionStatus.signedOut);
}

class PageCallController extends TeleconsultationController {
  PageCallController(super.id, this.initial);
  final CallState initial;
  int joined = 0, waiting = 0, left = 0, settings = 0, interrupted = 0;
  bool? requestedCamera, requestedMicrophone;
  bool deny = false;
  @override
  CallState build() => initial;
  @override
  Future<void> refresh() async {}
  @override
  void setVisible(bool visible) {}
  @override
  Future<void> enterWaitingRoom() async {
    waiting++;
    state = state.copyWith(phase: CallPhase.waiting);
  }

  void admitted() => state = CallState(session: room(admission: 'ADMITTED'));
  @override
  Future<void> join({bool camera = false, bool microphone = false}) async {
    joined++;
    requestedCamera = camera;
    requestedMicrophone = microphone;
    state = state.copyWith(
      phase: deny ? CallPhase.permissionDenied : CallPhase.connected,
      cameraEnabled: !deny && camera,
      microphoneEnabled: !deny && microphone,
    );
  }

  @override
  Future<void> leave() async {
    left++;
    state = state.copyWith(phase: CallPhase.ended);
  }

  @override
  Future<void> interrupt({bool inactive = false}) async {
    interrupted++;
    state = state.copyWith(
      phase: CallPhase.interrupted,
      cameraEnabled: false,
      microphoneEnabled: false,
    );
  }

  @override
  Future<void> openSettings() async {
    settings++;
  }
}

Future<ProviderContainer> pumpRoom(
  WidgetTester tester,
  PageCallController call, {
  bool french = false,
}) async {
  final container = ProviderContainer(
    overrides: [
      sessionControllerProvider.overrideWith(VideoSessionIdentity.new),
      teleconsultationControllerProvider(roomId).overrideWith(() => call),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(french ? 'fr' : 'en'),
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const TeleconsultationRoomPage(id: roomId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    'waiting room does not capture and admission enables explicit joining',
    (tester) async {
      final call = PageCallController(roomId, CallState(session: room()));
      await pumpRoom(tester, call);
      expect(find.text('Dr Healthys'), findsOneWidget);
      expect(call.joined, 0);
      expect(find.text('Join call'), findsNothing);
      await tester.tap(find.text('Enter waiting room'));
      await tester.pumpAndSettle();
      expect(call.waiting, 1);
      call.admitted();
      await tester.pumpAndSettle();
      expect(call.joined, 0);
      await tester.ensureVisible(find.text('Join call'));
      await tester.tap(find.text('Join call'));
      await tester.pumpAndSettle();
      expect(call.joined, 1);
      expect(call.requestedCamera, isFalse);
      expect(call.requestedMicrophone, isFalse);
      expect(find.text('Call in progress'), findsOneWidget);
    },
  );
  testWidgets(
    'permission refusal offers settings without displaying raw errors',
    (tester) async {
      final call = PageCallController(
        roomId,
        CallState(session: room(admission: 'ADMITTED')),
      )..deny = true;
      await pumpRoom(tester, call);
      await tester.tap(find.text('Enable my camera'));
      await tester.ensureVisible(find.text('Join call'));
      await tester.tap(find.text('Join call'));
      await tester.pumpAndSettle();
      expect(call.requestedCamera, isTrue);
      expect(find.text('Permission denied'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(call.settings, 1);
    },
  );
  testWidgets('ended session cannot enter waiting room or join', (
    tester,
  ) async {
    final call = PageCallController(
      roomId,
      CallState(
        phase: CallPhase.ended,
        session: room(status: 'COMPLETED'),
      ),
    );
    await pumpRoom(tester, call, french: true);
    expect(find.text('Consultation terminée'), findsOneWidget);
    expect(find.text('Rejoindre l’appel'), findsNothing);
    expect(find.text('Entrer en salle d’attente'), findsNothing);
  });
  testWidgets('patient leaves only after confirmation', (tester) async {
    final call = PageCallController(
      roomId,
      CallState(
        phase: CallPhase.connected,
        session: room(admission: 'ADMITTED'),
      ),
    );
    await pumpRoom(tester, call);
    await tester.scrollUntilVisible(find.text('Leave call'), 300);
    await tester.tap(find.text('Leave call'));
    await tester.pumpAndSettle();
    expect(call.left, 0);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(call.left, 0);
    await tester.tap(find.text('Leave call'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(call.left, 1);
  });
  testWidgets('reconnection and interruption require an explicit rejoin', (
    tester,
  ) async {
    final call = PageCallController(
      roomId,
      CallState(
        phase: CallPhase.reconnecting,
        session: room(admission: 'ADMITTED'),
      ),
    );
    await pumpRoom(tester, call);
    expect(find.text('Reconnecting…'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(call.interrupted, 1);
    expect(call.joined, 0);
    expect(
      find.text('Call interrupted. Join again to resume.'),
      findsOneWidget,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  testWidgets('logout hides room identity and metadata immediately', (
    tester,
  ) async {
    final call = PageCallController(roomId, CallState(session: room()));
    final container = await pumpRoom(tester, call);
    expect(find.text('Dr Healthys'), findsOneWidget);
    (container.read(sessionControllerProvider.notifier) as VideoSessionIdentity)
        .signOut();
    await tester.pumpAndSettle();
    expect(find.text('Dr Healthys'), findsNothing);
    expect(find.text('VIDEO-1811'), findsNothing);
  });
  testWidgets('controlled call error never displays backend secrets', (
    tester,
  ) async {
    final call = PageCallController(
      roomId,
      CallState(
        phase: CallPhase.failed,
        session: room(),
        error: const AppException(
          kind: AppErrorKind.server,
          message: 'SECRET-LIVEKIT-TOKEN',
        ),
      ),
    );
    await pumpRoom(tester, call);
    expect(find.text('SECRET-LIVEKIT-TOKEN'), findsNothing);
    expect(
      find.text('Connection unavailable. Refresh and try again.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'session list uses server pagination and opens the selected room',
    (tester) async {
      final pages = <int>[];
      final container = ProviderContainer(
        overrides: [
          sessionControllerProvider.overrideWith(VideoSessionIdentity.new),
          videoSessionsProvider.overrideWith((ref, query) async {
            pages.add(query.page);
            return VideoSessionPage(
              content: [room()],
              totalElements: 21,
              totalPages: 2,
              number: query.page,
              size: 20,
            );
          }),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/teleconsultations',
        routes: [
          GoRoute(
            path: '/teleconsultations',
            builder: (_, _) => const TeleconsultationsPage(),
          ),
          GoRoute(
            path: '/teleconsultations/:id',
            name: 'teleconsultation-room',
            builder: (_, state) =>
                Scaffold(body: Text('Room ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('VIDEO-1811'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(pages.last, 1);
      await tester.tap(find.text('VIDEO-1811'));
      await tester.pumpAndSettle();
      expect(find.text('Room $roomId'), findsOneWidget);
    },
  );
  test(
    'teleconsultation routes survive authentication and reject hostile destinations',
    () {
      expect(safeReturnPath('/teleconsultations'), '/teleconsultations');
      expect(
        safeReturnPath('/teleconsultations/$roomId'),
        '/teleconsultations/$roomId',
      );
      expect(
        safeReturnPath('https://attacker.example/teleconsultations/$roomId'),
        '/',
      );
      expect(safeReturnPath('/teleconsultations/not-a-uuid'), '/');
    },
  );
}
