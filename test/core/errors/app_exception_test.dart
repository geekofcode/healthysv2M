import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/errors/app_exception.dart';

void main() {
  DioException failure(Object? body, {int status = 400}) {
    final request = RequestOptions(
      path: '/patients',
      headers: {'X-Correlation-ID': 'request-id'},
    );
    return DioException(
      requestOptions: request,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: request,
        statusCode: status,
        data: body,
      ),
    );
  }

  test('maps Spring validation errors and correlation identifier', () {
    final result = AppException.fromDio(
      failure({
        'message': 'Validation échouée',
        'code': 'VALIDATION_ERROR',
        'correlationId': 'server-id',
        'violations': [
          {'field': 'email', 'message': 'Format invalide'},
          {'field': 'email', 'defaultMessage': 'Requis'},
        ],
      }),
    );
    expect(result.kind, AppErrorKind.validation);
    expect(result.code, 'VALIDATION_ERROR');
    expect(result.correlationId, 'server-id');
    expect(result.fieldErrors['email'], ['Format invalide', 'Requis']);
  });

  test('handles non-JSON gateway failures and map-shaped field errors', () {
    final gateway = AppException.fromDio(
      failure('<html>bad gateway</html>', status: 502),
    );
    expect(gateway.kind, AppErrorKind.server);
    expect(gateway.correlationId, 'request-id');
    expect(gateway.message, isNot(contains('html')));
    final validation = AppException.fromDio(
      failure({
        'fieldErrors': {
          'name': 'Requis',
          'email': ['Invalide'],
          'unexpected': 42,
        },
      }),
    );
    expect(validation.fieldErrors, {
      'name': ['Requis'],
      'email': ['Invalide'],
    });
  });

  test(
    'classifies session expiry and timeout without exposing exception details',
    () {
      expect(
        AppException.fromDio(failure(null, status: 401)).kind,
        AppErrorKind.unauthorized,
      );
      final timeout = AppException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.receiveTimeout,
          error: 'secret-token',
        ),
      );
      expect(timeout.kind, AppErrorKind.timeout);
      expect(timeout.toString(), isNot(contains('secret-token')));
    },
  );
  test('untrusted support metadata cannot leak diagnostics into UI', () {
    final result = AppException.fromDio(
      failure({
        'code': 'Bearer private-token',
        'correlationId': 'private-token\npatient-identity',
      }, status: 503),
    );
    expect(result.code, isNull);
    expect(result.correlationId, 'request-id');
    expect(result.toString(), isNot(contains('private-token')));
  });
}
