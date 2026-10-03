import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/messaging/application/messaging_providers.dart';
import 'package:healthysv2/features/messaging/data/messaging_repository.dart';
import 'package:healthysv2/features/messaging/presentation/conversation_page.dart';
import 'package:healthysv2/features/messaging/presentation/messaging_connection_banner.dart';
import 'package:healthysv2/features/teleconsultations/application/teleconsultation_providers.dart';

import 'messaging_pages_test.dart' as messaging;
import 'teleconsultation_pages_test.dart' as video;

void main() {
  for (final width in [320.0, 768.0, 1200.0]) {
    testWidgets('video layout adapts at $width without starting capture', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final call = video.PageCallController(
        video.roomId,
        CallState(
          phase: CallPhase.connected,
          session: video.room(),
          cameraEnabled: true,
          media: _PreviewMedia(),
        ),
      );
      await video.pumpRoom(tester, call);
      expect(
        find.byKey(
          Key(
            width >= 872
                ? 'teleconsultation-wide-video'
                : 'teleconsultation-compact-video',
          ),
        ),
        findsOneWidget,
      );
      expect(call.joined, 0);
      final remoteSize = tester.getSize(
        find.byKey(const Key('remote-preview')),
      );
      final localSize = tester.getSize(find.byKey(const Key('local-preview')));
      expect(remoteSize.width, greaterThan(localSize.width));
      expect(localSize.width, lessThanOrEqualTo(width / 2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('disconnected banner supports compact large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: MessagingConnectionBanner(
              status: MessagingConnectionStatus.disconnected,
              onRetry: () => retries++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Reconnect'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact composer remains usable above keyboard at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(messaging.Session.new),
          messagingRepositoryProvider.overrideWithValue(messaging.Repository()),
          messagingConnectionProvider(
            messaging.cid,
          ).overrideWith(() => messaging.Connection(messaging.cid)),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.8)),
            child: child!,
          ),
          home: const ConversationPage(id: messaging.cid),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Message conservé');
    expect(find.text('Message conservé'), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PreviewMedia implements TeleconsultationMedia {
  @override
  Widget videoView({required bool local}) => ColoredBox(
    key: Key(local ? 'local-preview' : 'remote-preview'),
    color: local ? Colors.blue : Colors.black,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
