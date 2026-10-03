import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/appointment.dart';

abstract interface class AppointmentRepository {
  Future<AppointmentPage> list(
    AppointmentListQuery query, {
    CancelToken? cancelToken,
  });
  Future<AppointmentSummary> detail(String id, {CancelToken? cancelToken});
  Future<BookingOptions> bookingOptions({CancelToken? cancelToken});
  Future<List<AppointmentSlot>> availability(
    AvailabilityQuery query, {
    CancelToken? cancelToken,
  });
  Future<AppointmentSummary> create({
    required String organizationId,
    required String professionalId,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    String? reason,
    CancelToken? cancelToken,
  });
  Future<AppointmentSummary> cancel(
    String id, {
    String? reason,
    CancelToken? cancelToken,
  });
  Future<AppointmentSummary> reschedule(
    String id, {
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    String? reason,
    CancelToken? cancelToken,
  });
}

class DioAppointmentRepository implements AppointmentRepository {
  DioAppointmentRepository(this.dio);
  final Dio dio;
  static const _path = 'patients/me/appointments';
  // The backend derives ownership from the principal; never submit patientId.
  @override
  Future<AppointmentPage> list(
    AppointmentListQuery query, {
    CancelToken? cancelToken,
  }) => _request(
    () => dio.get<Object?>(
      _path,
      queryParameters: {
        'view': query.view.name,
        'page': query.page,
        'size': query.size,
      },
      cancelToken: cancelToken,
    ),
    AppointmentPage.fromJson,
  );
  @override
  Future<AppointmentSummary> detail(String id, {CancelToken? cancelToken}) =>
      _request(
        () => dio.get<Object?>(
          '$_path/${Uri.encodeComponent(id)}',
          cancelToken: cancelToken,
        ),
        AppointmentSummary.fromJson,
      );
  @override
  Future<BookingOptions> bookingOptions({CancelToken? cancelToken}) => _request(
    () => dio.get<Object?>('$_path/booking-options', cancelToken: cancelToken),
    BookingOptions.fromJson,
  );
  @override
  Future<List<AppointmentSlot>> availability(
    AvailabilityQuery query, {
    CancelToken? cancelToken,
  }) => _request(
    () => dio.get<Object?>(
      '$_path/availability',
      queryParameters: {
        'organizationId': query.organizationId,
        'professionalId': query.professionalId,
        'from': query.from.toUtc().toIso8601String(),
        'to': query.to.toUtc().toIso8601String(),
        if (query.excludeAppointmentId != null)
          'excludeAppointmentId': query.excludeAppointmentId,
      },
      cancelToken: cancelToken,
    ),
    (json) {
      final slots = json['slots'];
      if (slots is! List) {
        throw const FormatException('Invalid availability response');
      }
      return List.unmodifiable(
        slots.map((slot) {
          if (slot is! Map<String, dynamic>) {
            throw const FormatException('Invalid availability response');
          }
          return AppointmentSlot.fromJson(slot);
        }),
      );
    },
  );
  @override
  Future<AppointmentSummary> create({
    required String organizationId,
    required String professionalId,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    String? reason,
    CancelToken? cancelToken,
  }) => _mutate(_path, {
    'organizationId': organizationId,
    'professionalId': professionalId,
    ..._times(scheduledStart, scheduledEnd),
    'reason': ?reason,
  }, cancelToken);
  @override
  Future<AppointmentSummary> cancel(
    String id, {
    String? reason,
    CancelToken? cancelToken,
  }) => _mutate('$_path/${Uri.encodeComponent(id)}/cancel', {
    'reason': ?reason,
  }, cancelToken);
  @override
  Future<AppointmentSummary> reschedule(
    String id, {
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    String? reason,
    CancelToken? cancelToken,
  }) => _mutate('$_path/${Uri.encodeComponent(id)}/reschedule', {
    ..._times(scheduledStart, scheduledEnd),
    'reason': ?reason,
  }, cancelToken);

  Map<String, String> _times(DateTime start, DateTime end) => {
    'scheduledStart': start.toUtc().toIso8601String(),
    'scheduledEnd': end.toUtc().toIso8601String(),
  };
  Future<AppointmentSummary> _mutate(
    String path,
    Map<String, Object?> data,
    CancelToken? token,
  ) => _request(
    () => dio.post<Object?>(
      path,
      data: data,
      cancelToken: token,
      options: Options(extra: {'retryOnUnauthorized': false}),
    ),
    AppointmentSummary.fromJson,
  );

  Future<T> _request<T>(
    Future<Response<Object?>> Function() send,
    T Function(Map<String, dynamic>) decode,
  ) async {
    try {
      final response = await send();
      if (response.data is! Map<String, dynamic>) {
        throw const FormatException('Invalid appointment response');
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
    message: 'Les rendez-vous sont temporairement indisponibles.',
  );
}

final appointmentRepositoryProvider = Provider<AppointmentRepository>(
  (ref) => DioAppointmentRepository(ref.watch(dioProvider)),
);
