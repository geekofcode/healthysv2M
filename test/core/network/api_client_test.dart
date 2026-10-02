import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/core/network/api_client.dart';
import 'package:healthysv2/core/storage/token_store.dart';

class MemoryTokens implements TokenStore {
  String? token = 'access-token';
  bool fail = false;
  @override
  Future<String?> readAccessToken() async {
    if (fail) throw StateError('secure-storage-unavailable');
    return token;
  }

  @override
  Future<void> writeAccessToken(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

class RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{"message":"Session expirée","code":"AUTH_EXPIRED"}',
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
  late MemoryTokens tokens;
  late RecordingAdapter adapter;
  late Dio dio;
  setUp(() {
    tokens = MemoryTokens();
    adapter = RecordingAdapter();
    dio = createApiClient(
      baseUrl: Uri.parse('https://api.healthys.test/api/v1'),
      tokenStore: tokens,
    );
    dio.httpClientAdapter = adapter;
  });
  tearDown(() => dio.close());

  test('uses current secure token and preserves versioned API path', () async {
    await dio.get('patients');
    tokens.token = 'updated-token';
    await dio.get('patients');
    expect(adapter.requests.first.uri.path, '/api/v1/patients');
    expect(
      adapter.requests.first.headers['Authorization'],
      'Bearer access-token',
    );
    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer updated-token',
    );
    final firstId = adapter.requests.first.headers['X-Correlation-ID'];
    expect(
      firstId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(adapter.requests.last.headers['X-Correlation-ID'], isNot(firstId));
  });

  test(
    'public requests do not read tokens and cleared sessions omit bearer',
    () async {
      tokens.fail = true;
      await dio.get('public', options: Options(extra: {'requiresAuth': false}));
      expect(
        adapter.requests.last.headers.containsKey('Authorization'),
        isFalse,
      );
      tokens.fail = false;
      await tokens.clear();
      await dio.get('patients');
      expect(
        adapter.requests.last.headers.containsKey('Authorization'),
        isFalse,
      );
    },
  );

  test('disables redirects even when a caller requests them', () async {
    await dio.get('patients', options: Options(followRedirects: true));
    expect(adapter.requests.single.followRedirects, isFalse);
  });

  test(
    'rejects foreign destinations before credentials reach an adapter',
    () async {
      await expectLater(
        dio.get('https://outside.test/patients'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test('maps backend failures to structured presentation errors', () async {
    adapter.status = 401;
    try {
      await dio.get('patients');
      fail('Expected unauthorized response');
    } on DioException catch (error) {
      expect(error.error, isA<AppException>());
      final mapped = error.error! as AppException;
      expect(mapped.kind, AppErrorKind.unauthorized);
      expect(mapped.code, 'AUTH_EXPIRED');
      expect(mapped.correlationId, isNotNull);
    }
  });

  test(
    'secure storage failures fail closed without sending a request',
    () async {
      tokens.fail = true;
      await expectLater(dio.get('patients'), throwsA(isA<DioException>()));
      expect(adapter.requests, isEmpty);
    },
  );
}
