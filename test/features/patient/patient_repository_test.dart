import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/patient/application/patient_dashboard_provider.dart';
import 'package:healthysv2/features/patient/data/patient_repository.dart';
import 'package:healthysv2/features/patient/domain/patient_dashboard.dart';

Map<String, dynamic> contract() => {
  'person': {
    'id': 'person1',
    'firstName': 'Ada',
    'lastName': 'Smith',
    'contacts': [],
  },
  'patient': {'id': 'patient1', 'personId': 'person1', 'patientNumber': 'P001'},
  'insurances': [],
  'addresses': [],
  'flags': [
    {'id': 'flag', 'label': 'Alert', 'active': true},
    {'id': 'old', 'active': false},
  ],
  'allergies': [
    {'id': 'allergy', 'allergen': 'Peanut', 'status': 'ACTIVE'},
    {'id': 'old', 'allergen': 'Milk', 'status': 'RESOLVED'},
  ],
};

class Adapter implements HttpClientAdapter {
  int status = 200;
  Object body = contract();
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
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

class PatientSession extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'person1'}),
  );
  void signOut() => state = const SessionState(status: SessionStatus.signedOut);
}

class DelayedRepository implements PatientRepository {
  final pending = Completer<PatientDashboard>();
  CancelToken? token;
  @override
  Future<PatientDashboard> fetchDashboard({CancelToken? cancelToken}) {
    token = cancelToken;
    return pending.future;
  }
}

void main() {
  test('insurance validity uses inclusive local calendar dates', () {
    final policy = PatientInsurance(
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 2),
    );
    expect(
      policy.coverageOn(DateTime(2026, 10, 2, 23, 59)),
      InsuranceCoverage.active,
    );
    expect(policy.coverageOn(DateTime(2026, 10, 3)), InsuranceCoverage.expired);
    expect(
      policy.coverageOn(DateTime(2026, 9, 30)),
      InsuranceCoverage.upcoming,
    );
    expect(
      const PatientInsurance().coverageOn(DateTime(2026)),
      InsuranceCoverage.unknown,
    );
  });
  test(
    'maps only active alerts and rejects inconsistent or partial records',
    () {
      final dashboard = PatientDashboard.fromJson(contract());
      expect(dashboard.flags.map((f) => f.id), ['flag']);
      expect(dashboard.allergies.map((a) => a.id), ['allergy']);
      final mismatched = contract();
      mismatched['patient']['personId'] = 'other';
      expect(
        () => PatientDashboard.fromJson(mismatched),
        throwsFormatException,
      );
      final partial = contract()..remove('allergies');
      expect(() => PatientDashboard.fromJson(partial), throwsFormatException);
    },
  );
  test('calls self endpoint without accepting a patient identifier', () async {
    final adapter = Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1/'));
    dio.httpClientAdapter = adapter;
    final repository = DioPatientRepository(dio);
    final dashboard = await repository.fetchDashboard();
    expect(adapter.request?.uri.path, '/api/v1/patients/me/dashboard');
    expect(adapter.request?.queryParameters, isEmpty);
    expect(dashboard.patient.patientNumber, 'P001');
    for (final status in [403, 404, 500]) {
      adapter.status = status;
      await expectLater(
        repository.fetchDashboard(),
        throwsA(
          isA<AppException>().having((e) => e.statusCode, 'status', status),
        ),
      );
    }
    adapter.status = 200;
    adapter.body = {'patient': null};
    await expectLater(
      repository.fetchDashboard(),
      throwsA(isA<AppException>()),
    );
    dio.close();
  });
  test(
    'logout cancels patient retrieval and discards a late medical response',
    () async {
      final session = PatientSession();
      final repository = DelayedRepository();
      final container = ProviderContainer(
        overrides: [
          sessionControllerProvider.overrideWith(() => session),
          patientRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final subscription = container.listen(
        patientDashboardProvider,
        (_, _) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(patientDashboardProvider).isLoading, true);
      session.signOut();
      expect(await container.read(patientDashboardProvider.future), isNull);
      expect(repository.token?.isCancelled, true);
      repository.pending.complete(PatientDashboard.fromJson(contract()));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(patientDashboardProvider).value, isNull);
      subscription.close();
      container.dispose();
    },
  );
}
