import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/maternal_child.dart';

abstract interface class MaternalChildRepository {
  Future<MaternalPage<PregnancySummary>> pregnancies(
    MaternalChildListQuery query, {
    CancelToken? cancelToken,
  });
  Future<PregnancyDetail> pregnancy(String id, {CancelToken? cancelToken});
  Future<MaternalPage<ChildSummary>> children(
    MaternalChildListQuery query, {
    CancelToken? cancelToken,
  });
  Future<ChildDetail> child(String childPatientId, {CancelToken? cancelToken});
}

class DioMaternalChildRepository implements MaternalChildRepository {
  DioMaternalChildRepository(this.dio);
  final Dio dio;
  static const _path = 'patients/me/maternal-child';
  @override
  Future<MaternalPage<PregnancySummary>> pregnancies(
    MaternalChildListQuery query, {
    CancelToken? cancelToken,
  }) => _request(
    '$_path/pregnancies',
    (json) => MaternalPage.fromJson(json, PregnancySummary.fromJson),
    query: query,
    cancelToken: cancelToken,
  );
  @override
  Future<MaternalPage<ChildSummary>> children(
    MaternalChildListQuery query, {
    CancelToken? cancelToken,
  }) => _request(
    '$_path/children',
    (json) => MaternalPage.fromJson(json, ChildSummary.fromJson),
    query: query,
    cancelToken: cancelToken,
  );
  @override
  Future<PregnancyDetail> pregnancy(String id, {CancelToken? cancelToken}) =>
      _request('$_path/pregnancies/${Uri.encodeComponent(id)}', (json) {
        final result = PregnancyDetail.fromJson(json);
        if (result.pregnancy.id != id) {
          throw const FormatException('Mismatched pregnancy');
        }
        return result;
      }, cancelToken: cancelToken);
  @override
  Future<ChildDetail> child(
    String childPatientId, {
    CancelToken? cancelToken,
  }) => _request('$_path/children/${Uri.encodeComponent(childPatientId)}', (
    json,
  ) {
    final result = ChildDetail.fromJson(json);
    if (result.child.childPatientId != childPatientId) {
      throw const FormatException('Mismatched child');
    }
    return result;
  }, cancelToken: cancelToken);
  Future<T> _request<T>(
    String path,
    T Function(Map<String, dynamic>) decode, {
    MaternalChildListQuery? query,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dio.get<Object?>(
        path,
        queryParameters: query == null
            ? null
            : {'page': query.page, 'size': query.size},
        cancelToken: cancelToken,
      );
      if (response.data is! Map<String, dynamic>) {
        throw const FormatException('Invalid notebook response');
      }
      return decode(response.data! as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.error case final AppException mapped) {
        throw mapped;
      }
      throw AppException.fromDio(error);
    } on FormatException {
      throw _invalidResponse;
    } on TypeError {
      throw _invalidResponse;
    }
  }

  static const _invalidResponse = AppException(
    kind: AppErrorKind.unknown,
    message: 'Le carnet mère-enfant est temporairement indisponible.',
  );
}

final maternalChildRepositoryProvider = Provider<MaternalChildRepository>(
  (ref) => DioMaternalChildRepository(ref.watch(dioProvider)),
);
