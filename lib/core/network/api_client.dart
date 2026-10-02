import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../../features/auth/application/session_controller.dart';
import '../../features/auth/domain/session.dart';
import '../errors/app_exception.dart';
import '../storage/token_store.dart';

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final session = ref.read(sessionControllerProvider.notifier);
  final dio = createApiClient(
    baseUrl: config.apiBaseUrl,
    tokenStore: ref.watch(tokenStoreProvider),
    accessToken: ({bool forceRefresh = false}) =>
        session.accessToken(forceRefresh: forceRefresh),
    expireSession: session.expire,
    sessionRevision: () => session.revision,
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

typedef AccessTokenReader = Future<String?> Function({bool forceRefresh});

Dio createApiClient({
  required Uri baseUrl,
  required TokenStore tokenStore,
  AccessTokenReader? accessToken,
  Future<void> Function()? expireSession,
  int Function()? sessionRevision,
}) {
  final url = baseUrl.toString();
  final dio = Dio(
    BaseOptions(
      baseUrl: url.endsWith('/') ? url : '$url/',
      followRedirects: false,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(
    ApiInterceptor(
      tokenStore,
      baseUrl,
      dio,
      accessToken: accessToken,
      expireSession: expireSession,
      sessionRevision: sessionRevision,
    ),
  );
  return dio;
}

class ApiInterceptor extends Interceptor {
  ApiInterceptor(
    this._tokens,
    this._baseUrl,
    this._dio, {
    this.accessToken,
    this.expireSession,
    this.sessionRevision,
  });

  final Dio _dio;
  final AccessTokenReader? accessToken;
  final Future<void> Function()? expireSession;
  final int Function()? sessionRevision;
  static const _revisionKey = 'healthys.sessionRevision';
  static const _retryKey = 'healthys.authRetried';

  final TokenStore _tokens;
  final Uri _baseUrl;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.followRedirects = false;
    // Absolute third-party URLs must never receive HEALTH'YS credentials.
    if (options.uri.origin != _baseUrl.origin) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: const AppException(
            kind: AppErrorKind.forbidden,
            message: 'Adresse API non autorisée.',
          ),
        ),
      );
      return;
    }
    options.headers['X-Correlation-ID'] = _correlationId();
    try {
      if (options.extra['requiresAuth'] != false) {
        final revision = sessionRevision?.call();
        if (options.extra[_retryKey] == true && !_sameSession(options)) {
          throw SessionExpiredException();
        }
        options.extra[_revisionKey] = revision;
        final token = accessToken == null
            ? await _tokens.readAccessToken()
            : await accessToken!();
        if (revision != sessionRevision?.call()) {
          throw SessionExpiredException();
        }
        options.headers = {
          for (final entry in options.headers.entries)
            if (entry.key.toLowerCase() != 'authorization')
              entry.key: entry.value,
        };
        if (accessToken != null && (token == null || token.isEmpty)) {
          throw SessionExpiredException();
        }
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
      handler.next(options);
    } catch (error) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: AppException(
            kind: error is SessionExpiredException
                ? AppErrorKind.unauthorized
                : AppErrorKind.network,
            message: error is SessionExpiredException
                ? 'Session expirée.'
                : 'Session temporairement indisponible.',
          ),
        ),
      );
    }
  }

  bool _sameSession(RequestOptions request) =>
      request.extra['requiresAuth'] == false ||
      sessionRevision == null ||
      request.extra[_revisionKey] == sessionRevision!();

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!_sameSession(response.requestOptions)) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          type: DioExceptionType.cancel,
          error: const AppException(
            kind: AppErrorKind.cancelled,
            message: 'La session a changé.',
          ),
        ),
      );
      return;
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    if (err.response?.statusCode == 401 &&
        request.extra['requiresAuth'] != false &&
        accessToken != null &&
        _sameSession(request)) {
      if (request.extra[_retryKey] == true) {
        await _expireSafely();
      } else {
        try {
          final oldBearer = request.headers['Authorization'];
          var token = await accessToken!();
          if ('Bearer $token' == oldBearer) {
            token = await accessToken!(forceRefresh: true);
          }
          if (!_sameSession(request) || token == null) {
            throw SessionExpiredException();
          }
          // Mutations may opt out: refresh credentials without repeating an action.
          // Streams cannot be replayed safely either.
          if (request.extra['retryOnUnauthorized'] != false &&
              request.data is! Stream &&
              request.data is! FormData) {
            final retry = request.copyWith(
              extra: {...request.extra, _retryKey: true},
              data: request.data,
            );
            final response = await _dio.fetch<dynamic>(retry);
            handler.resolve(response);
            return;
          }
        } on DioException catch (retryError) {
          handler.next(retryError);
          return;
        } catch (failure) {
          handler.next(
            err.copyWith(
              error: AppException(
                kind: failure is SessionExpiredException
                    ? AppErrorKind.unauthorized
                    : AppErrorKind.network,
                message: failure is SessionExpiredException
                    ? 'Session expirée.'
                    : 'Renouvellement temporairement indisponible.',
              ),
            ),
          );
          return;
        }
      }
    }
    handler.next(
      err.copyWith(
        error: err.error is AppException
            ? err.error
            : AppException.fromDio(err),
      ),
    );
  }

  Future<void> _expireSafely() async {
    try {
      await expireSession?.call();
    } catch (_) {
      /* UI remains signed out. */
    }
  }

  String _correlationId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
