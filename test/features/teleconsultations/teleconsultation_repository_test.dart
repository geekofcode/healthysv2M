import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/teleconsultations/data/teleconsultation_repository.dart';
import 'package:healthysv2/features/teleconsultations/domain/teleconsultation.dart';

const id = '11111111-1111-4111-8111-111111111111';
Map<String, dynamic> video() => {
  'id': id,
  'sessionNumber': 'V-1',
  'status': 'ACTIVE',
  'canJoin': true,
  'scheduledStart': '2026-10-03T14:00:00Z',
  'participants': [],
  'waitingRoom': [],
};

class Adapter implements HttpClientAdapter {
  Object? body;
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

void main() {
  late Dio dio;
  late Adapter adapter;
  late DioTeleconsultationRepository repository;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1/'));
    adapter = Adapter();
    dio.httpClientAdapter = adapter;
    repository = DioTeleconsultationRepository(dio);
  });
  tearDown(() => dio.close());
  test('page endpoint keeps standard metadata and submitted page', () async {
    adapter.body = {
      'content': [video()],
      'page': {'number': 2, 'size': 10, 'totalElements': 24, 'totalPages': 3},
    };
    final page = await repository.list(
      const VideoSessionQuery(page: 2, size: 10),
    );
    expect(page.content.single.canJoin, true);
    expect(page.totalPages, 3);
    expect(adapter.requests.single.uri.path, '/api/v1/video-sessions/page');
    expect(adapter.requests.single.queryParameters, {'page': 2, 'size': 10});
  });
  test('detail accepts only matching authorized session identity', () async {
    adapter.body = video();
    final result = await repository.detail(id);
    expect(result.id, id);
    adapter.body = {...video(), 'id': '22222222-2222-4222-8222-222222222222'};
    await expectLater(repository.detail(id), throwsA(isA<AppException>()));
  });
  test('malformed UUID is never accepted as session', () async {
    adapter.body = {...video(), 'id': 'arbitrary-route'};
    await expectLater(repository.detail(id), throwsA(isA<AppException>()));
  });
  test('timezone-naive timestamps are rejected', () async {
    adapter.body = {...video(), 'scheduledStart': '2026-10-03T14:00:00'};
    await expectLater(repository.detail(id), throwsA(isA<AppException>()));
  });
  test(
    'waiting room and leave mutations never replay after auth refresh',
    () async {
      adapter.body = null;
      await repository.enterWaitingRoom(id);
      await repository.leave(id);
      expect(adapter.requests.map((r) => r.uri.path), [
        '/api/v1/video-sessions/$id/waiting-room',
        '/api/v1/video-sessions/$id/leave',
      ]);
      expect(
        adapter.requests.every((r) => r.extra['retryOnUnauthorized'] == false),
        true,
      );
    },
  );
  test(
    'token is memory-only and its representation excludes credentials',
    () async {
      adapter.body = {
        'serverUrl': 'wss://rtc.test',
        'token': 'secret-token',
        'roomName': 'room',
        'expiresAt': '2026-10-03T14:00:00Z',
      };
      final token = await repository.token(id);
      expect(token.toString(), isNot(contains('secret-token')));
      expect(adapter.requests.single.extra['retryOnUnauthorized'], false);
    },
  );
  test('admission does not derive from another waiting entry', () {
    final session = VideoSession.fromJson({
      ...video(),
      'canJoin': false,
      'waitingRoom': [
        {'patientId': id, 'status': 'ADMITTED'},
      ],
    });
    expect(session.canJoin, false);
  });
  test('forbidden detail preserves safe structured status', () async {
    adapter.status = 403;
    adapter.body = {'code': 'ACCESS_DENIED'};
    await expectLater(
      repository.detail(id),
      throwsA(
        isA<AppException>().having(
          (e) => e.kind,
          'kind',
          AppErrorKind.forbidden,
        ),
      ),
    );
  });
}
