import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/prescription.dart';

abstract interface class PrescriptionRepository {
  Future<PrescriptionPage> list(
    PrescriptionListQuery query, {
    CancelToken? cancelToken,
  });
  Future<PrescriptionDetail> detail(String id, {CancelToken? cancelToken});
}

class DioPrescriptionRepository implements PrescriptionRepository {
  DioPrescriptionRepository(this.dio);
  final Dio dio;
  static const _path = 'patients/me/prescriptions';
  @override
  Future<PrescriptionPage> list(
    PrescriptionListQuery query, {
    CancelToken? cancelToken,
  }) => _request(
    () => dio.get<Object?>(
      _path,
      queryParameters: {'page': query.page, 'size': query.size},
      cancelToken: cancelToken,
    ),
    PrescriptionPage.fromJson,
  );
  @override
  Future<PrescriptionDetail> detail(String id, {CancelToken? cancelToken}) =>
      _request(
        () => dio.get<Object?>(
          '$_path/${Uri.encodeComponent(id)}',
          cancelToken: cancelToken,
        ),
        (json) {
          final detail = PrescriptionDetail.fromJson(json);
          if (detail.prescription.id != id) {
            throw const FormatException('Mismatched prescription');
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
        throw const FormatException('Invalid prescription response');
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
    message: 'Les prescriptions sont temporairement indisponibles.',
  );
}

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>(
  (ref) => DioPrescriptionRepository(ref.watch(dioProvider)),
);
