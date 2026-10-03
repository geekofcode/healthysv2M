import 'dart:async';
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
  List<int> statuses = [];
  Completer<void>? pending;
  DioExceptionType? failureType;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await pending?.future;
    if (failureType != null) {
      throw DioException(
        requestOptions: options,
        type: failureType!,
        error: 'private diagnostic with token',
      );
    }
    return ResponseBody.fromString(
      '{"message":"Session expirée","code":"AUTH_EXPIRED"}',
      statuses.isEmpty ? status : statuses.removeAt(0),
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
  test(
    'mutation opt-out refreshes credentials without replaying a booking',
    () async {
      adapter.statuses = [401, 200];
      var token = 'old';
      var refreshes = 0;
      dio.close();
      dio = createApiClient(
        baseUrl: Uri.parse('https://api.healthys.test/api/v1'),
        tokenStore: tokens,
        accessToken: ({bool forceRefresh = false}) async {
          if (forceRefresh) {
            token = 'new';
            refreshes++;
          }
          return token;
        },
      )..httpClientAdapter = adapter;
      await expectLater(
        dio.post(
          'patients/me/appointments',
          data: {'reason': 'Consultation'},
          options: Options(extra: {'retryOnUnauthorized': false}),
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            401,
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
      expect(refreshes, 1);
      await dio.get('patients/me/appointments');
      expect(adapter.requests.last.headers['Authorization'], 'Bearer new');
    },
  );

  test('401 refreshes once and retries using rotated token', () async {
    var token = 'old';
    var refreshes = 0;
    var expired = 0;
    dio = createApiClient(
      baseUrl: Uri.parse('https://api.healthys.test/api/v1'),
      tokenStore: tokens,
      accessToken: ({bool forceRefresh = false}) async {
        if (forceRefresh) {
          refreshes++;
          token = 'new';
        }
        return token;
      },
      expireSession: () async {
        expired++;
      },
      sessionRevision: () => 1,
    );
    dio.httpClientAdapter = adapter;
    adapter.statuses = [401, 200];
    await dio.get('persons/me');
    expect(refreshes, 1);
    expect(expired, 0);
    expect(adapter.requests.last.headers['Authorization'], 'Bearer new');
  });

  test('second 401 expires without an infinite retry', () async {
    var expired = 0;
    dio = createApiClient(
      baseUrl: Uri.parse('https://api.healthys.test/api/v1'),
      tokenStore: tokens,
      accessToken: ({bool forceRefresh = false}) async =>
          forceRefresh ? 'new' : 'old',
      expireSession: () async {
        expired++;
      },
      sessionRevision: () => 1,
    );
    dio.httpClientAdapter = adapter;
    adapter.status = 401;
    await expectLater(dio.get('patients'), throwsA(isA<DioException>()));
    expect(adapter.requests.length, 2);
    expect(expired, 1);
  });

  test('refresh outage preserves session and prevents a replay', () async {
    var expired = 0;
    dio = createApiClient(
      baseUrl: Uri.parse('https://api.healthys.test/api/v1'),
      tokenStore: tokens,
      accessToken: ({bool forceRefresh = false}) async {
        if (forceRefresh) throw StateError('offline');
        return 'old';
      },
      expireSession: () async {
        expired++;
      },
      sessionRevision: () => 1,
    );
    dio.httpClientAdapter = adapter;
    adapter.status = 401;
    await expectLater(dio.get('patients'), throwsA(isA<DioException>()));
    expect(adapter.requests.length, 1);
    expect(expired, 0);
  });

  test('token read interrupted by logout never sends a request', () async {
    var revision = 1;
    dio = createApiClient(
      baseUrl: Uri.parse('https://api.healthys.test/api/v1'),
      tokenStore: tokens,
      accessToken: ({bool forceRefresh = false}) async {
        revision++;
        return 'old';
      },
      sessionRevision: () => revision,
    );
    dio.httpClientAdapter = adapter;
    await expectLater(dio.get('patients'), throwsA(isA<DioException>()));
    expect(adapter.requests, isEmpty);
  });

  test('public requests work with a session revision guard', () async {
    dio = createApiClient(
      baseUrl: Uri.parse('https://api.healthys.test/api/v1'),
      tokenStore: tokens,
      accessToken: ({bool forceRefresh = false}) async =>
          throw StateError('must not read'),
      sessionRevision: () => 1,
    );
    dio.httpClientAdapter = adapter;
    await dio.get('public', options: Options(extra: {'requiresAuth': false}));
    expect(adapter.requests.length, 1);
  });
  test('unmarked mutations refresh but are never replayed after 401', () async {
    var refreshes = 0;
    dio.close();
    dio = createApiClient(
      baseUrl: Uri.parse('https://api.healthys.test/api/v1'),
      tokenStore: tokens,
      accessToken: ({bool forceRefresh = false}) async {
        if (forceRefresh) refreshes++;
        return forceRefresh ? 'new' : 'old';
      },
    )..httpClientAdapter = adapter;
    adapter.status = 401;
    await expectLater(
      dio.post('patients/me/actions', data: {'action': 'create'}),
      throwsA(isA<DioException>()),
    );
    expect(adapter.requests, hasLength(1));
    expect(refreshes, 1);
  });

  for (final status in [200, 401, 422, 503]) {
    test('late $status response is discarded after account switch', () async {
      var revision = 1;
      var refreshes = 0;
      var expired = 0;
      dio.close();
      dio = createApiClient(
        baseUrl: Uri.parse('https://api.healthys.test/api/v1'),
        tokenStore: tokens,
        accessToken: ({bool forceRefresh = false}) async {
          if (forceRefresh) refreshes++;
          return 'old';
        },
        sessionRevision: () => revision,
        expireSession: () async {
          expired++;
        },
      )..httpClientAdapter = adapter;
      adapter.status = status;
      adapter.pending = Completer<void>();
      final request = dio.get('patients/me');
      final expectation = expectLater(
        request,
        throwsA(
          isA<DioException>()
              .having((e) => e.type, 'type', DioExceptionType.cancel)
              .having((e) => e.response, 'previous account response', isNull),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(adapter.requests, hasLength(1));
      revision++;
      adapter.pending!.complete();
      await expectation;
      expect(refreshes, 0);
      expect(expired, 0);
    });
  }

  test('offline transport failure is safe and never replayed', () async {
    adapter.failureType = DioExceptionType.connectionError;
    try {
      await dio.get('patients/me');
      fail('Expected offline failure');
    } on DioException catch (error) {
      final safe = error.error! as AppException;
      expect(safe.kind, AppErrorKind.network);
      expect(safe.message, isNot(contains('private diagnostic')));
      expect(tokens.token, 'access-token');
      expect(adapter.requests, hasLength(1));
    }
  });
  test(
    'account switch during refresh discards the old account failure',
    () async {
      var revision = 1;
      final pending = Completer<String?>();
      dio.close();
      dio = createApiClient(
        baseUrl: Uri.parse('https://api.healthys.test/api/v1'),
        tokenStore: tokens,
        sessionRevision: () => revision,
        accessToken: ({bool forceRefresh = false}) async =>
            forceRefresh ? pending.future : 'old',
      )..httpClientAdapter = adapter;
      adapter.status = 401;
      final request = dio.get('patients/me');
      final expectation = expectLater(
        request,
        throwsA(
          isA<DioException>()
              .having((e) => e.type, 'type', DioExceptionType.cancel)
              .having((e) => e.response, 'previous response', isNull),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      revision++;
      pending.complete('new-account-token');
      await expectation;
      expect(adapter.requests, hasLength(1));
    },
  );
}
