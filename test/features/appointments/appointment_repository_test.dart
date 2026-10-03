import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/appointments/data/appointment_repository.dart';
import 'package:healthysv2/features/appointments/domain/appointment.dart';
import 'appointment_fixtures.dart';

class Adapter implements HttpClientAdapter {
  Object? body = pageJson();
  int status = 200;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late Adapter adapter;
  late DioAppointmentRepository repository;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1/'));
    adapter = Adapter();
    dio.httpClientAdapter = adapter;
    repository = DioAppointmentRepository(dio);
  });
  tearDown(() => dio.close());
  test(
    'lists own appointments with requested view and server pagination',
    () async {
      final result = await repository.list(
        const AppointmentListQuery(
          view: AppointmentView.past,
          page: 2,
          size: 10,
        ),
      );
      expect(result.content.single.professionalName, 'Jane Smith');
      expect(result.content.single.scheduledStart.isUtc, true);
      expect(result.totalElements, 1);
      expect(
        adapter.requests.single.uri.path,
        '/api/v1/patients/me/appointments',
      );
      expect(adapter.requests.single.queryParameters, {
        'view': 'past',
        'page': 2,
        'size': 10,
      });
      expect(
        adapter.requests.single.queryParameters.containsKey('patientId'),
        false,
      );
    },
  );
  test(
    'availability uses explicit UTC range and optional own-appointment exclusion',
    () async {
      adapter.body = {
        'slots': [
          {
            'scheduledStart': '2026-11-01T14:00:00Z',
            'scheduledEnd': '2026-11-01T14:30:00Z',
          },
        ],
      };
      final query = AvailabilityQuery(
        organizationId: 'org',
        professionalId: 'pro',
        from: DateTime.parse('2026-11-01T09:00:00-05:00'),
        to: DateTime.utc(2026, 11, 2),
        excludeAppointmentId: 'existing',
      );
      final slots = await repository.availability(query);
      expect(slots.single.scheduledStart, DateTime.utc(2026, 11, 1, 14));
      expect(
        adapter.requests.single.queryParameters['from'],
        '2026-11-01T14:00:00.000Z',
      );
      expect(
        adapter.requests.single.queryParameters['excludeAppointmentId'],
        'existing',
      );
    },
  );
  test(
    'booking options keep named organizations and professional affiliations',
    () async {
      adapter.body = {
        'organizations': [
          {'id': 'org', 'name': 'Clinic'},
        ],
        'professionals': [
          {
            'id': 'pro',
            'organizationId': 'org',
            'name': 'Jane Smith',
            'professionalType': 'DOCTOR',
          },
        ],
      };
      final options = await repository.bookingOptions();
      expect(options.organizations.single.name, 'Clinic');
      expect(options.professionals.single.organizationId, 'org');
      expect(
        adapter.requests.single.path,
        'patients/me/appointments/booking-options',
      );
    },
  );
  test(
    'create cancel and reschedule send only exact self-service fields and never replay',
    () async {
      adapter.body = appointmentJson();
      final start = DateTime.utc(2026, 11, 1, 14);
      final end = start.add(const Duration(minutes: 30));
      await repository.create(
        organizationId: 'org',
        professionalId: 'pro',
        scheduledStart: start,
        scheduledEnd: end,
        reason: 'Follow-up',
      );
      await repository.cancel('appointment-1', reason: 'Unavailable');
      await repository.reschedule(
        'appointment-1',
        scheduledStart: start,
        scheduledEnd: end,
      );
      expect(adapter.requests.map((r) => r.method), everyElement('POST'));
      expect(
        adapter.requests.map((r) => r.extra['retryOnUnauthorized']),
        everyElement(false),
      );
      expect(adapter.requests.first.data, {
        'organizationId': 'org',
        'professionalId': 'pro',
        'scheduledStart': '2026-11-01T14:00:00.000Z',
        'scheduledEnd': '2026-11-01T14:30:00.000Z',
        'reason': 'Follow-up',
      });
      expect(adapter.requests[1].data, {'reason': 'Unavailable'});
      expect(
        (adapter.requests.last.data as Map).keys,
        unorderedEquals(['scheduledStart', 'scheduledEnd']),
      );
      expect(
        adapter.requests[1].path,
        'patients/me/appointments/appointment-1/cancel',
      );
      expect(
        adapter.requests.last.path,
        'patients/me/appointments/appointment-1/reschedule',
      );
    },
  );
  test(
    'conflict is structured and malformed clinical data is safely rejected',
    () async {
      adapter.status = 409;
      adapter.body = {
        'code': 'SLOT_UNAVAILABLE',
        'message': 'Créneau indisponible',
        'correlationId': 'request-1',
      };
      await expectLater(
        repository.cancel('appointment-1'),
        throwsA(
          isA<AppException>()
              .having((error) => error.statusCode, 'status', 409)
              .having((error) => error.code, 'code', 'SLOT_UNAVAILABLE'),
        ),
      );
      expect(adapter.requests, hasLength(1));
      adapter.status = 200;
      adapter.body = {
        ...appointmentJson(),
        'scheduledStart': '2026-11-01T14:00:00',
      };
      await expectLater(
        repository.detail('appointment-1'),
        throwsA(isA<AppException>()),
      );
    },
  );
}
