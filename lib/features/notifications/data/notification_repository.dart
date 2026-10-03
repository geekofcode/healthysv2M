import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/notifications.dart';

abstract interface class NotificationRepository {
  Future<NotificationPage> list(
    NotificationQuery query, {
    CancelToken? cancelToken,
  });
  Future<HealthysNotification> detail(String id, {CancelToken? cancelToken});
  Future<int> unreadCount({CancelToken? cancelToken});
  Future<HealthysNotification> markRead(String id, {CancelToken? cancelToken});
  Future<void> markAllRead({CancelToken? cancelToken});
  Future<NotificationPreferences> preferences({CancelToken? cancelToken});
  Future<NotificationPreferences> savePreferences(
    NotificationPreferences preferences, {
    CancelToken? cancelToken,
  });
  Future<String> registerDevice(
    String installationId,
    String token,
    String platform,
    String revocationToken, {
    CancelToken? cancelToken,
  });
  Future<void> unregisterDevice(String installationId, {String? accessToken});
  Future<void> revokeDevice(String installationId, String revocationToken);
}

class DioNotificationRepository implements NotificationRepository {
  DioNotificationRepository(this.dio);
  final Dio dio;
  Future<T> _perform<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DioException catch (error) {
      if (error.error case final AppException mapped) {
        throw mapped;
      }
      throw AppException.fromDio(error);
    } on FormatException {
      throw _invalid;
    } on TypeError {
      throw _invalid;
    }
  }

  Map<String, dynamic> _json(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid notification response');
    }
    return value;
  }

  @override
  Future<NotificationPage> list(
    NotificationQuery query, {
    CancelToken? cancelToken,
  }) => _perform(
    () async => NotificationPage.fromJson(
      _json(
        (await dio.get<Object?>(
          'notifications',
          queryParameters: {
            'page': query.page,
            'size': query.size,
            'unreadOnly': query.unreadOnly,
          },
          cancelToken: cancelToken,
        )).data,
      ),
    ),
  );
  Future<HealthysNotification> _notification(
    String id,
    String method, {
    CancelToken? cancelToken,
  }) => _perform(() async {
    if (!notificationUuid(id)) {
      throw const FormatException('Invalid id');
    }
    final response = await dio.request<Object?>(
      'notifications/$id${method == 'PATCH' ? '/read' : ''}',
      options: Options(
        method: method,
        extra: {'retryOnUnauthorized': method == 'GET'},
      ),
      cancelToken: cancelToken,
    );
    final result = HealthysNotification.fromJson(_json(response.data));
    if (result.id != id) {
      throw const FormatException('Mismatched id');
    }
    return result;
  });
  @override
  Future<HealthysNotification> detail(String id, {CancelToken? cancelToken}) =>
      _notification(id, 'GET', cancelToken: cancelToken);
  @override
  Future<HealthysNotification> markRead(
    String id, {
    CancelToken? cancelToken,
  }) => _notification(id, 'PATCH', cancelToken: cancelToken);
  @override
  Future<int> unreadCount({CancelToken? cancelToken}) => _perform(
    () async =>
        _json(
              (await dio.get<Object?>(
                'notifications/unread-count',
                cancelToken: cancelToken,
              )).data,
            )['unreadCount']
            as int,
  );
  @override
  Future<void> markAllRead({CancelToken? cancelToken}) => _perform(() async {
    await dio.post<Object?>(
      'notifications/read-all',
      options: Options(extra: {'retryOnUnauthorized': false}),
      cancelToken: cancelToken,
    );
  });
  @override
  Future<NotificationPreferences> preferences({CancelToken? cancelToken}) =>
      _perform(
        () async => NotificationPreferences.fromJson(
          _json(
            (await dio.get<Object?>(
              'notifications/preferences',
              cancelToken: cancelToken,
            )).data,
          ),
        ),
      );
  @override
  Future<NotificationPreferences> savePreferences(
    NotificationPreferences preferences, {
    CancelToken? cancelToken,
  }) => _perform(
    () async => NotificationPreferences.fromJson(
      _json(
        (await dio.put<Object?>(
          'notifications/preferences',
          data: preferences.toJson(),
          options: Options(extra: {'retryOnUnauthorized': false}),
          cancelToken: cancelToken,
        )).data,
      ),
    ),
  );
  @override
  Future<String> registerDevice(
    String installationId,
    String token,
    String platform,
    String revocationToken, {
    CancelToken? cancelToken,
  }) => _perform(() async {
    final response = await dio.put<Object?>(
      'notifications/devices/$installationId',
      data: {
        'token': token,
        'platform': platform,
        'revocationToken': revocationToken,
      },
      options: Options(extra: {'retryOnUnauthorized': false}),
      cancelToken: cancelToken,
    );
    return _json(response.data)['revocationToken'] as String;
  });
  @override
  Future<void> unregisterDevice(String installationId, {String? accessToken}) =>
      _perform(() async {
        await dio.delete<Object?>(
          'notifications/devices/$installationId',
          options: accessToken == null
              ? null
              : Options(
                  headers: {'Authorization': 'Bearer $accessToken'},
                  extra: {'requiresAuth': false, 'retryOnUnauthorized': false},
                ),
        );
      });
  @override
  Future<void> revokeDevice(String installationId, String revocationToken) =>
      _perform(() async {
        await dio.post<Object?>(
          'notifications/devices/revoke',
          data: {
            'installationId': installationId,
            'revocationToken': revocationToken,
          },
          options: Options(
            extra: {'requiresAuth': false, 'retryOnUnauthorized': false},
          ),
        );
      });
  static const _invalid = AppException(
    kind: AppErrorKind.unknown,
    message: 'Notifications temporairement indisponibles.',
  );
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => DioNotificationRepository(ref.watch(dioProvider)),
);
