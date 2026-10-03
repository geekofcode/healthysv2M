import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/messaging/application/messaging_providers.dart';
import 'package:healthysv2/features/messaging/data/messaging_repository.dart';
import 'package:healthysv2/features/messaging/domain/messaging.dart';
import 'package:healthysv2/features/documents/domain/document.dart';

Map<String, dynamic> messageJson({String conversation = 'conversation'}) => {
  'id': 'message',
  'conversationId': conversation,
  'senderPersonId': 'sender',
  'senderName': 'Doctor',
  'type': 'TEXT',
  'content': 'hello',
  'sentAt': '2026-10-02T12:00:00Z',
  'editedAt': null,
  'deletedAt': null,
  'documentIds': <String>[],
  'readByCurrentUser': false,
  'readByOthersCount': 2,
};
Map<String, dynamic> pageJson(List<Object> content) => {
  'content': content,
  'page': {
    'number': 0,
    'size': 20,
    'totalElements': content.length,
    'totalPages': 1,
    'first': true,
    'last': true,
  },
};

class Adapter implements HttpClientAdapter {
  Object? body = pageJson([messageJson()]);
  int status = 200;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class Session extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'one'}),
  );
  void signOut() => state = const SessionState(status: SessionStatus.signedOut);
  void change() => state = const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'two'}),
  );
}

class PendingRepository implements MessagingRepository {
  final pending = <Completer<MessagingPage<Message>>>[];
  final tokens = <CancelToken?>[];
  @override
  Future<MessagingPage<Message>> messages(
    MessagingQuery query, {
    CancelToken? cancelToken,
  }) {
    final result = Completer<MessagingPage<Message>>();
    pending.add(result);
    tokens.add(cancelToken);
    return result.future;
  }

  @override
  Future<MessagingPage<ConversationSummary>> conversations(
    MessagingQuery query, {
    CancelToken? cancelToken,
  }) async =>
      MessagingPage.fromJson(pageJson([]), ConversationSummary.fromJson);
  @override
  Future<ConversationDetail> conversation(
    String id, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<Message> send(
    String conversationId,
    String content, {
    List<String> documentIds = const [],
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<void> markRead(String id, {CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<MessagingAttachment> upload(
    String conversationId,
    String fileName,
    Uint8List bytes, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<MessagingAttachment> attachment(
    String conversationId,
    String documentId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<DownloadedDocument> download(
    String conversationId,
    String documentId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<List<MessagingRecipient>> recipients({
    CancelToken? cancelToken,
  }) async => [];
  @override
  Future<ConversationDetail> create(
    String recipientPersonId,
    String subject, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}

void main() {
  late Dio dio;
  late Adapter adapter;
  late DioMessagingRepository repository;
  setUp(() {
    adapter = Adapter();
    dio = Dio(BaseOptions(baseUrl: 'https://host/api/v1/'))
      ..httpClientAdapter = adapter;
    repository = DioMessagingRepository(dio);
  });
  tearDown(() => dio.close(force: true));
  test(
    'paged REST messages decode read receipts specific to current user',
    () async {
      final result = await repository.messages(
        const MessagingQuery(conversationId: 'conversation', page: 2),
      );
      expect(result.content.single.readByCurrentUser, isFalse);
      expect(result.content.single.readByOthersCount, 2);
      expect(adapter.requests.single.queryParameters['page'], 2);
    },
  );
  test('mismatched conversation payload is rejected', () async {
    adapter.body = pageJson([messageJson(conversation: 'other')]);
    await expectLater(
      repository.messages(const MessagingQuery(conversationId: 'conversation')),
      throwsA(isA<AppException>()),
    );
  });
  test(
    'send opts out of mutation replay and never retries network errors',
    () async {
      adapter.body = messageJson();
      await repository.send('conversation', 'hello');
      expect(adapter.requests.single.extra['retryOnUnauthorized'], false);
      adapter.status = 503;
      await expectLater(
        repository.send('conversation', 'hello'),
        throwsA(isA<AppException>()),
      );
      expect(adapter.requests.length, 2);
    },
  );
  test(
    'empty sends and wrong upload signatures do not issue requests',
    () async {
      expect(
        () => repository.send('conversation', ' '),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repository.upload(
          'conversation',
          'bad.pdf',
          Uint8List.fromList([1, 2]),
        ),
        throwsA(isA<AppException>()),
      );
      expect(adapter.requests, isEmpty);
    },
  );
  test(
    'multipart upload sets verified supported MIME type and no auth replay',
    () async {
      adapter.body = {
        'id': 'attachment',
        'fileName': 'a.pdf',
        'mimeType': 'application/pdf',
        'sizeBytes': 5,
        'uploadedAt': '2026-10-02T12:00:00Z',
        'status': 'ACTIVE',
      };
      await repository.upload(
        'conversation',
        'a.pdf',
        Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d]),
      );
      final data = adapter.requests.single.data as FormData;
      expect(data.files.single.value.contentType.toString(), 'application/pdf');
      expect(adapter.requests.single.extra['retryOnUnauthorized'], false);
    },
  );
  test('participant role may be absent and invalid instants rejected', () {
    expect(
      Participant.fromJson({
        'personId': 'id',
        'role': null,
        'displayName': null,
        'status': 'ACTIVE',
      }).role,
      isNull,
    );
    expect(
      () =>
          Message.fromJson({...messageJson(), 'sentAt': '2026-10-02T12:00:00'}),
      throwsFormatException,
    );
  });
  for (final logout in [true, false]) {
    test(
      logout
          ? 'logout cancels pending messages'
          : 'account switch cancels old message response',
      () async {
        final session = Session();
        final repository = PendingRepository();
        final container = ProviderContainer(
          overrides: [
            sessionControllerProvider.overrideWith(() => session),
            messagingRepositoryProvider.overrideWithValue(repository),
          ],
        );
        const query = MessagingQuery(conversationId: 'conversation');
        final subscription = container.listen(
          messagesProvider(query),
          (_, _) {},
        );
        await Future<void>.delayed(Duration.zero);
        if (logout) {
          session.signOut();
        } else {
          session.change();
        }
        await Future<void>.delayed(Duration.zero);
        expect(repository.tokens.first!.isCancelled, true);
        repository.pending.first.complete(
          MessagingPage.fromJson(pageJson([messageJson()]), Message.fromJson),
        );
        if (!logout) {
          repository.pending.last.complete(
            MessagingPage.fromJson(pageJson([]), Message.fromJson),
          );
        }
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(messagesProvider(query)).value?.content,
          isNot(contains(isA<Message>())),
        );
        subscription.close();
        container.dispose();
      },
    );
  }
}
