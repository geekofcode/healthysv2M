import 'package:dio/dio.dart';

enum AppErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  validation,
  server,
  cancelled,
  unknown,
}

/// Safe, structured error for presentation. Never retains request credentials.
class AppException implements Exception {
  const AppException({
    required this.kind,
    required this.message,
    this.code,
    this.statusCode,
    this.correlationId,
    this.fieldErrors = const {},
  });

  final AppErrorKind kind;
  final String message;
  final String? code;
  final int? statusCode;
  final String? correlationId;
  final Map<String, List<String>> fieldErrors;

  factory AppException.fromDio(DioException error) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final data = body is Map ? body : const <String, dynamic>{};
    final kind = _kind(error.type, status);
    return AppException(
      kind: kind,
      message: kind == AppErrorKind.server
          ? _defaultMessage(kind)
          : _text(data['message']) ?? _defaultMessage(kind),
      code: _text(data['code']),
      statusCode: status,
      correlationId:
          _text(data['correlationId']) ??
          error.response?.headers.value('X-Correlation-ID') ??
          _text(error.requestOptions.headers['X-Correlation-ID']),
      fieldErrors: _fields(data['violations'] ?? data['fieldErrors']),
    );
  }

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  static AppErrorKind _kind(DioExceptionType type, int? status) {
    if (type == DioExceptionType.cancel) return AppErrorKind.cancelled;
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout) {
      return AppErrorKind.timeout;
    }
    if (type == DioExceptionType.connectionError) return AppErrorKind.network;
    if (status == 401) return AppErrorKind.unauthorized;
    if (status == 403) return AppErrorKind.forbidden;
    if (status == 400 || status == 422) return AppErrorKind.validation;
    if (status != null && status >= 500) return AppErrorKind.server;
    return AppErrorKind.unknown;
  }

  static String _defaultMessage(AppErrorKind kind) => switch (kind) {
    AppErrorKind.network => 'Connexion indisponible. Vérifiez votre réseau.',
    AppErrorKind.timeout => 'Le serveur met trop de temps à répondre.',
    AppErrorKind.unauthorized => 'Votre session a expiré. Reconnectez-vous.',
    AppErrorKind.forbidden => 'Vous ne disposez pas des droits nécessaires.',
    AppErrorKind.validation => 'Vérifiez les informations saisies.',
    AppErrorKind.server => 'Le service est temporairement indisponible.',
    AppErrorKind.cancelled => 'La demande a été annulée.',
    AppErrorKind.unknown => 'Une erreur est survenue. Réessayez.',
  };

  static Map<String, List<String>> _fields(Object? value) {
    final result = <String, List<String>>{};
    void add(Object? field, Object? message) {
      if (field is! String) return;
      final messages = message is List
          ? message.whereType<String>().toList()
          : message is String
          ? [message]
          : <String>[];
      if (messages.isNotEmpty) {
        result.putIfAbsent(field, () => []).addAll(messages);
      }
    }

    if (value is Map) value.forEach(add);
    if (value is List) {
      for (final entry in value.whereType<Map>()) {
        add(entry['field'], entry['message'] ?? entry['defaultMessage']);
      }
    }
    return Map.unmodifiable(
      result.map(
        (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
      ),
    );
  }

  @override
  String toString() =>
      'AppException(${kind.name}, code: $code, status: $statusCode)';
}
