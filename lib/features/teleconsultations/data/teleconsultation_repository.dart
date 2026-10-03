import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/teleconsultation.dart';

abstract interface class TeleconsultationRepository {
  Future<VideoSessionPage> list(
    VideoSessionQuery query, {
    CancelToken? cancelToken,
  });
  Future<VideoSession> detail(String id, {CancelToken? cancelToken});
  Future<void> enterWaitingRoom(String id, {CancelToken? cancelToken});
  Future<VideoSessionToken> token(String id, {CancelToken? cancelToken});
  Future<void> leave(String id, {CancelToken? cancelToken});
}

class DioTeleconsultationRepository implements TeleconsultationRepository {
  DioTeleconsultationRepository(this.dio);
  final Dio dio;
  static const path = 'video-sessions';
  String _item(String id) => '$path/${Uri.encodeComponent(id)}';
  @override
  Future<VideoSessionPage> list(
    VideoSessionQuery query, {
    CancelToken? cancelToken,
  }) => _request(
    () => dio.get<Object?>(
      '$path/page',
      queryParameters: {'page': query.page, 'size': query.size},
      cancelToken: cancelToken,
    ),
    (data) => VideoSessionPage.fromJson(data as Map<String, dynamic>),
  );
  @override
  Future<VideoSession> detail(String id, {CancelToken? cancelToken}) =>
      _request(() => dio.get<Object?>(_item(id), cancelToken: cancelToken), (
        data,
      ) {
        final session = VideoSession.fromJson(data as Map<String, dynamic>);
        if (session.id.toLowerCase() != id.toLowerCase()) {
          throw const FormatException("Mismatched video session");
        }
        return session;
      });
  @override
  Future<void> enterWaitingRoom(String id, {CancelToken? cancelToken}) =>
      _post('${_item(id)}/waiting-room', cancelToken);
  @override
  Future<VideoSessionToken> token(String id, {CancelToken? cancelToken}) =>
      _request(
        () => dio.post<Object?>(
          '${_item(id)}/token',
          cancelToken: cancelToken,
          options: _once,
        ),
        (data) => VideoSessionToken.fromJson(data as Map<String, dynamic>),
      );
  @override
  Future<void> leave(String id, {CancelToken? cancelToken}) =>
      _post('${_item(id)}/leave', cancelToken);
  static final _once = Options(extra: {'retryOnUnauthorized': false});
  Future<void> _post(String path, CancelToken? token) => _request(
    () => dio.post<Object?>(path, cancelToken: token, options: _once),
    (_) {},
  );
  Future<T> _request<T>(
    Future<Response<Object?>> Function() send,
    T Function(Object?) decode,
  ) async {
    try {
      return decode((await send()).data);
    } on DioException catch (e) {
      if (e.error case final AppException mapped) {
        throw mapped;
      }
      throw AppException.fromDio(e);
    } on FormatException {
      throw _invalid;
    } on TypeError {
      throw _invalid;
    }
  }

  static const _invalid = AppException(
    kind: AppErrorKind.unknown,
    message: 'La téléconsultation est temporairement indisponible.',
  );
}

final teleconsultationRepositoryProvider = Provider<TeleconsultationRepository>(
  (ref) => DioTeleconsultationRepository(ref.watch(dioProvider)),
);
