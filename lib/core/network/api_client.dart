import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../errors/app_exception.dart';
import '../storage/token_store.dart';

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = createApiClient(
    baseUrl: config.apiBaseUrl,
    tokenStore: ref.watch(tokenStoreProvider),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

Dio createApiClient({required Uri baseUrl, required TokenStore tokenStore}) {
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
  dio.interceptors.add(ApiInterceptor(tokenStore, baseUrl));
  return dio;
}

class ApiInterceptor extends Interceptor {
  ApiInterceptor(this._tokens, this._baseUrl);

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
        final token = await _tokens.readAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
      handler.next(options);
    } catch (_) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: const AppException(
            kind: AppErrorKind.unknown,
            message: 'Impossible d’accéder à la session sécurisée.',
          ),
        ),
      );
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(
      err.copyWith(
        error: err.error is AppException
            ? err.error
            : AppException.fromDio(err),
      ),
    );
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
