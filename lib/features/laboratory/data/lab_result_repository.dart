import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/lab_result.dart';

abstract interface class LabResultRepository {
  Future<LabResultPage> list(
    LabResultListQuery query, {
    CancelToken? cancelToken,
  });
  Future<LabResultDetail> detail(String id, {CancelToken? cancelToken});
}

class DioLabResultRepository implements LabResultRepository {
  DioLabResultRepository(this.dio);
  final Dio dio;
  static const _path = 'patients/me/lab-results';
  @override
  Future<LabResultPage> list(
    LabResultListQuery query, {
    CancelToken? cancelToken,
  }) => _request(
    () => dio.get<Object?>(
      _path,
      queryParameters: {'page': query.page, 'size': query.size},
      cancelToken: cancelToken,
    ),
    LabResultPage.fromJson,
  );
  @override
  Future<LabResultDetail> detail(String id, {CancelToken? cancelToken}) =>
      _request(
        () => dio.get<Object?>(
          '$_path/${Uri.encodeComponent(id)}',
          cancelToken: cancelToken,
        ),
        (json) {
          final detail = LabResultDetail.fromJson(json);
          if (detail.result.id != id) {
            throw const FormatException('Mismatched lab_result');
          }
          return detail;
        },
      );
  Future<T> _request<T>(
    Future<Response<Object?>> Function() send,
    T Function(Map<String, dynamic>) decode,
  ) async {
    try {
      final response = await send();
      if (response.data is! Map<String, dynamic>) {
        throw const FormatException('Invalid lab_result response');
      }
      return decode(response.data! as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.error case final AppException mapped) throw mapped;
      throw AppException.fromDio(error);
    } on FormatException {
      throw _invalidResponse;
    } on TypeError {
      throw _invalidResponse;
    }
  }

  static const _invalidResponse = AppException(
    kind: AppErrorKind.unknown,
    message: 'Les résultats de laboratoire sont temporairement indisponibles.',
  );
}

final labResultRepositoryProvider = Provider<LabResultRepository>(
  (ref) => DioLabResultRepository(ref.watch(dioProvider)),
);
