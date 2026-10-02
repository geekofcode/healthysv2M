import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/consultation.dart';

abstract interface class ConsultationRepository {
  Future<ConsultationPage> list(
    ConsultationListQuery query, {
    CancelToken? cancelToken,
  });
  Future<ConsultationDetail> detail(String id, {CancelToken? cancelToken});
}

class DioConsultationRepository implements ConsultationRepository {
  DioConsultationRepository(this.dio);
  final Dio dio;
  static const _path = 'patients/me/consultations';
  @override
  Future<ConsultationPage> list(
    ConsultationListQuery query, {
    CancelToken? cancelToken,
  }) => _request(
    () => dio.get<Object?>(
      _path,
      queryParameters: {'page': query.page, 'size': query.size},
      cancelToken: cancelToken,
    ),
    ConsultationPage.fromJson,
  );
  @override
  Future<ConsultationDetail> detail(String id, {CancelToken? cancelToken}) =>
      _request(
        () => dio.get<Object?>(
          '$_path/${Uri.encodeComponent(id)}',
          cancelToken: cancelToken,
        ),
        (json) {
          final detail = ConsultationDetail.fromJson(json);
          if (detail.consultation.id != id) {
            throw const FormatException('Mismatched consultation');
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
        throw const FormatException('Invalid consultation response');
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
    message: 'Les consultations sont temporairement indisponibles.',
  );
}

final consultationRepositoryProvider = Provider<ConsultationRepository>(
  (ref) => DioConsultationRepository(ref.watch(dioProvider)),
);
