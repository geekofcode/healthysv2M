import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/app/healthys_app.dart';
import 'package:healthysv2/app/router/app_router.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/documents/domain/document.dart';
import 'package:healthysv2/features/messaging/application/messaging_providers.dart';
import 'package:healthysv2/features/messaging/data/messaging_repository.dart';
import 'package:healthysv2/features/messaging/domain/messaging.dart';
import 'package:healthysv2/features/messaging/presentation/messaging_file_picker.dart';
import 'package:healthysv2/features/patient/application/patient_dashboard_provider.dart';

const cid = '00000000-0000-0000-0000-000000000901';
const docId = '00000000-0000-0000-0000-000000000902';
final instant = DateTime.utc(2026, 10, 2, 10);
const participants = [
  Participant(
    personId: 'doctor-private-id',
    displayName: 'Dr Alice',
    role: 'DOCTOR',
    status: 'ACTIVE',
  ),
];
const sampleConversation = ConversationDetail(
  id: cid,
  conversationNumber: 'C-901',
  type: 'DIRECT',
  subject: 'Suivi',
  status: 'ACTIVE',
  participants: participants,
);
Message incoming({
  String id = 'incoming',
  List<String> documents = const [],
  bool own = false,
  int othersRead = 0,
}) => Message(
  id: id,
  conversationId: cid,
  senderPersonId: own ? 'person-1' : 'doctor-private-id',
  senderName: 'Dr Alice',
  type: documents.isEmpty ? 'TEXT' : 'DOCUMENT',
  content: own ? 'Merci' : 'Bonjour',
  sentAt: instant,
  documentIds: documents,
  readByCurrentUser: own,
  readByOthersCount: othersRead,
);

class Session extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'person-1'}),
  );
  @override
  Future<String?> accessToken({bool forceRefresh = false}) async => 'token';
  @override
  Future<void> expire() async {
    state = const SessionState(status: SessionStatus.expired);
  }
}

class Connection extends MessagingConnectionController {
  Connection(super.conversationId);
  int resumes = 0, suspends = 0, reconnects = 0;
  @override
  MessagingConnectionState build() =>
      const MessagingConnectionState(MessagingConnectionStatus.connected);
  @override
  void resume() {
    resumes++;
  }

  @override
  void suspend() {
    suspends++;
  }

  @override
  void reconnect() {
    reconnects++;
  }
}

class ListConnection extends MessagingListConnectionController {
  int resumes = 0, suspends = 0, reconnects = 0;
  @override
  MessagingConnectionState build() =>
      const MessagingConnectionState(MessagingConnectionStatus.connected);
  @override
  void resume() {
    resumes++;
  }

  @override
  void suspend() {
    suspends++;
  }

  @override
  void reconnect() {
    reconnects++;
  }
}

class Repository implements MessagingRepository {
  bool empty = false;
  bool attachments = false;
  Object? error;
  final pages = <int>[];
  final reads = <String>[];
  List<Message>? messageList;
  int sent = 0, downloads = 0, uploads = 0;
  String? recipient, sentContent;
  List<String> sentDocuments = [];
  Completer<Message>? pendingSend;
  Completer<MessagingPage<Message>>? pendingMessages;
  MessagingPage<T> page<T>(List<T> content, int number) => MessagingPage(
    content: content,
    page: number,
    size: 20,
    totalElements: empty ? 0 : 21,
    totalPages: empty ? 0 : 2,
    last: empty || number == 1,
  );
  @override
  Future<MessagingPage<ConversationSummary>> conversations(
    MessagingQuery query, {
    CancelToken? cancelToken,
  }) async {
    pages.add(query.page);
    if (error != null) {
      throw error!;
    }
    return page(
      empty
          ? []
          : [
              ConversationSummary(
                id: cid,
                conversationNumber: 'C-901',
                type: 'DIRECT',
                subject: 'Suivi',
                status: 'ACTIVE',
                lastMessage: 'Bonjour',
                lastMessageAt: instant,
                unreadCount: 2,
                participants: participants,
              ),
            ],
      query.page,
    );
  }

  @override
  Future<ConversationDetail> conversation(
    String id, {
    CancelToken? cancelToken,
  }) async => sampleConversation;
  @override
  Future<MessagingPage<Message>> messages(
    MessagingQuery query, {
    CancelToken? cancelToken,
  }) async {
    if (pendingMessages != null) {
      return pendingMessages!.future;
    }
    return page(
      empty
          ? []
          : messageList ??
                [
                  incoming(documents: attachments ? [docId] : []),
                ],
      query.page,
    );
  }

  @override
  Future<Message> send(
    String conversationId,
    String content, {
    List<String> documentIds = const [],
    CancelToken? cancelToken,
  }) async {
    sent++;
    sentContent = content;
    sentDocuments = documentIds;
    if (error != null) {
      throw error!;
    }
    return pendingSend == null
        ? incoming(id: 'sent', own: true)
        : pendingSend!.future;
  }

  @override
  Future<void> markRead(String messageId, {CancelToken? cancelToken}) async {
    reads.add(messageId);
  }

  @override
  Future<List<MessagingRecipient>> recipients({
    CancelToken? cancelToken,
  }) async => empty
      ? []
      : [
          const MessagingRecipient(
            personId: 'doctor-private-id',
            displayName: 'Dr Alice',
            professionalId: 'private-professional',
          ),
        ];
  @override
  Future<ConversationDetail> create(
    String recipientPersonId,
    String subject, {
    CancelToken? cancelToken,
  }) async {
    recipient = recipientPersonId;
    return sampleConversation;
  }

  @override
  Future<MessagingAttachment> upload(
    String conversationId,
    String fileName,
    Uint8List bytes, {
    CancelToken? cancelToken,
  }) async {
    uploads++;
    return attachment(conversationId, docId);
  }

  @override
  Future<MessagingAttachment> attachment(
    String conversationId,
    String documentId, {
    CancelToken? cancelToken,
  }) async => MessagingAttachment(
    id: docId,
    fileName: 'resultat.txt',
    mimeType: 'text/plain',
    sizeBytes: 6,
    uploadedAt: instant,
    status: 'ACTIVE',
  );
  @override
  Future<DownloadedDocument> download(
    String conversationId,
    String documentId, {
    CancelToken? cancelToken,
  }) async {
    downloads++;
    return DownloadedDocument(
      metadata: DocumentMetadata(
        id: docId,
        documentNumber: 'D-1',
        patientId: '',
        fileName: 'resultat.txt',
        mimeType: 'text/plain',
        sizeBytes: 6,
        uploadedAt: instant,
        status: 'ACTIVE',
      ),
      bytes: Uint8List.fromList('secret'.codeUnits),
    );
  }
}

class Picker implements MessagingFilePicker {
  @override
  Future<PickedMessagingFile?> pick() async => PickedMessagingFile(
    name: 'resultat.txt',
    bytes: Uint8List.fromList('secret'.codeUnits),
  );
}

Future<ProviderContainer> pump(
  WidgetTester tester,
  String path, {
  Repository? repository,
  bool french = false,
  bool settle = true,
}) async {
  tester.binding.platformDispatcher.localesTestValue = [
    Locale(french ? 'fr' : 'en'),
  ];
  addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
  final container = ProviderContainer(
    overrides: [
      sessionControllerProvider.overrideWith(Session.new),
      patientDashboardProvider.overrideWith((ref) async => null),
      messagingRepositoryProvider.overrideWithValue(repository ?? Repository()),
      messagingFilePickerProvider.overrideWithValue(Picker()),
      messagingListConnectionProvider.overrideWith(ListConnection.new),
      messagingConnectionProvider(cid).overrideWith(() => Connection(cid)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const HealthysApp()),
  );
  container.read(appRouterProvider).go(path);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  return container;
}

void main() {
  test('messaging return routes reject external and arbitrary IDs', () {
    for (final path in ['/messages', '/messages/new', '/messages/$cid']) {
      expect(safeReturnPath(path), path);
    }
    for (final path in [
      '/messages/private',
      '/messages/../profile',
      'https://evil.example/messages',
    ]) {
      expect(safeReturnPath(path), '/');
    }
  });
  testWidgets(
    'conversation list displays unread count and paging without private IDs',
    (tester) async {
      final repository = Repository();
      await pump(tester, '/messages', repository: repository);
      expect(find.text('Suivi'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('doctor-private-id'), findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(repository.pages.last, 1);
      await tester.tap(find.text('Suivi'));
      await tester.pumpAndSettle();
      expect(find.text('Dr Alice'), findsWidgets);
      expect(repository.reads, ['incoming']);
    },
  );
  testWidgets('empty conversation state is localized', (tester) async {
    await pump(
      tester,
      '/messages',
      repository: Repository()..empty = true,
      french: true,
    );
    expect(find.text('Aucune conversation.'), findsOneWidget);
  });
  testWidgets('private server error is controlled with retry', (tester) async {
    await pump(
      tester,
      '/messages',
      repository: Repository()
        ..error = const AppException(
          kind: AppErrorKind.server,
          message: 'private database diagnostic',
        ),
    );
    expect(find.text('private database diagnostic'), findsNothing);
    expect(
      find.text('The service is temporarily unavailable.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });
  testWidgets('outgoing read label requires an actual recipient receipt', (
    tester,
  ) async {
    final repository = Repository()
      ..messageList = [
        incoming(id: 'a', own: true),
        incoming(id: 'b', own: true, othersRead: 1),
      ];
    await pump(tester, '/messages/$cid', repository: repository, french: true);
    expect(find.text('Envoyé'), findsOneWidget);
    expect(find.text('Lu'), findsOneWidget);
    expect(repository.reads, isEmpty);
  });
  testWidgets('send is single-flight and retains composer until confirmed', (
    tester,
  ) async {
    final repository = Repository()..pendingSend = Completer<Message>();
    await pump(tester, '/messages/$cid', repository: repository);
    await tester.enterText(find.byType(TextField), 'Merci beaucoup');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(repository.sent, 1);
    expect(repository.sentContent, 'Merci beaucoup');
    expect(find.text('Merci beaucoup'), findsOneWidget);
    repository.pendingSend!.complete(incoming(id: 'new', own: true));
    await tester.pumpAndSettle();
    expect(find.text('Merci beaucoup'), findsNothing);
  });
  testWidgets('failed send keeps draft and warns to reconcile before retry', (
    tester,
  ) async {
    final repository = Repository();
    await pump(tester, '/messages/$cid', repository: repository, french: true);
    repository.error = const AppException(
      kind: AppErrorKind.network,
      message: 'secret',
    );
    await tester.enterText(find.byType(TextField), 'Mon message');
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();
    expect(find.text('Mon message'), findsOneWidget);
    expect(
      find.text('Actualisez l’historique avant de renvoyer.'),
      findsOneWidget,
    );
    expect(find.text('secret'), findsNothing);
  });
  testWidgets('attachment metadata does not download until explicit preview', (
    tester,
  ) async {
    final repository = Repository()..attachments = true;
    final container = await pump(
      tester,
      '/messages/$cid',
      repository: repository,
    );
    final connection =
        container.read(messagingConnectionProvider(cid).notifier) as Connection;
    await tester.tap(find.text('Attachment'));
    await tester.pumpAndSettle();
    expect(find.text('resultat.txt'), findsOneWidget);
    expect(connection.suspends, greaterThan(0));
    expect(repository.downloads, 0);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(repository.downloads, 1);
    expect(find.text('secret'), findsOneWidget);
  });
  testWidgets(
    'picked attachment is sent by scoped document ID with empty text',
    (tester) async {
      final repository = Repository();
      await pump(tester, '/messages/$cid', repository: repository);
      await tester.tap(find.byTooltip('Attach a file'));
      await tester.pumpAndSettle();
      expect(repository.uploads, 1);
      expect(find.text('resultat.txt'), findsOneWidget);
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(repository.sentDocuments, [docId]);
      expect(repository.sentContent, '');
    },
  );
  testWidgets('new conversation uses named authorized care team selection', (
    tester,
  ) async {
    final repository = Repository();
    await pump(tester, '/messages/new', repository: repository);
    expect(find.text('doctor-private-id'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dr Alice').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open conversation'));
    await tester.pumpAndSettle();
    expect(repository.recipient, 'doctor-private-id');
    expect(find.text('Suivi'), findsOneWidget);
  });
  testWidgets('background conversation does not mark arriving messages read', (
    tester,
  ) async {
    final repository = Repository()
      ..pendingMessages = Completer<MessagingPage<Message>>();
    final container = await pump(
      tester,
      '/messages/$cid',
      repository: repository,
      settle: false,
    );
    final connection =
        container.read(messagingConnectionProvider(cid).notifier) as Connection;
    final resumes = connection.resumes;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(connection.suspends, greaterThan(0));
    repository.pendingMessages!.complete(repository.page([incoming()], 0));
    await tester.pumpAndSettle();
    expect(repository.reads, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repository.reads, ['incoming']);
    expect(connection.resumes, greaterThan(resumes));
  });
}
