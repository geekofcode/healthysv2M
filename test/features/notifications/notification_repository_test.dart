import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/notifications/data/notification_repository.dart';
import 'package:healthysv2/features/notifications/domain/notifications.dart';

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

const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
Map<String, dynamic> json() => {
  'id': id,
  'type': 'MESSAGE',
  'body': 'Hello',
  'priority': 'NORMAL',
  'createdAt': '2026-10-03T00:00:00Z',
  'status': 'ACTIVE',
  'read': false,
};
void main() {
  late Dio dio;
  late Adapter adapter;
  late DioNotificationRepository repository;
  setUp(() {
    adapter = Adapter();
    dio = Dio(BaseOptions(baseUrl: 'https://api.example/api/v1/'))
      ..httpClientAdapter = adapter;
    repository = DioNotificationRepository(dio);
  });
  tearDown(() => dio.close(force: true));
  test('Notification query sends pagination and unread filter', () async {
    adapter.body = {
      'content': [json()],
      'page': {
        'number': 2,
        'size': 10,
        'totalElements': 21,
        'totalPages': 3,
        'last': true,
      },
    };
    final page = await repository.list(
      const NotificationQuery(page: 2, size: 10, unreadOnly: true),
    );
    expect(page.content.single.id, id);
    expect(adapter.requests.single.queryParameters, {
      'page': 2,
      'size': 10,
      'unreadOnly': true,
    });
  });
  test('Detail rejects mismatched recipient response identity', () async {
    adapter.body = {...json(), 'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'};
    await expectLater(repository.detail(id), throwsA(isA<AppException>()));
  });
  test('Recipient forbidden response maps to error', () async {
    adapter.status = 403;
    adapter.body = {};
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
  test(
    'Registration sends stable client capability without mutation replay',
    () async {
      adapter.body = {'revocationToken': 'capability'};
      await repository.registerDevice(id, 'fcm', 'ANDROID', 'capability');
      expect(adapter.requests.single.data, {
        'token': 'fcm',
        'platform': 'ANDROID',
        'revocationToken': 'capability',
      });
      expect(adapter.requests.single.extra['retryOnUnauthorized'], false);
    },
  );
  test(
    'Public revocation excludes auth and cannot trigger session refresh',
    () async {
      await repository.revokeDevice(id, 'capability');
      final request = adapter.requests.single;
      expect(request.path, 'notifications/devices/revoke');
      expect(request.extra['requiresAuth'], false);
      expect(request.headers['Authorization'], null);
      expect(request.data, {
        'installationId': id,
        'revocationToken': 'capability',
      });
    },
  );
  test('Mark read does not autoreplay mutation', () async {
    adapter.body = json();
    await repository.markRead(id);
    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.extra['retryOnUnauthorized'], false);
  });
}
