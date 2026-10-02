import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/patient/application/patient_medical_record_provider.dart';
import 'package:healthysv2/features/patient/data/patient_medical_record_repository.dart';
import 'package:healthysv2/features/patient/domain/patient_medical_record.dart';

Map<String, dynamic> medicalContract() => {
  'patient': {'id': 'patient1', 'personId': 'person1', 'patientNumber': 'P001'},
  'allergies': [
    {'id': 'a', 'allergen': 'Milk', 'status': 'RESOLVED'},
  ],
  'chronicDiseases': [
    {
      'id': 'c',
      'diagnosisCode': 'J45',
      'diagnosisLabel': 'Asthma',
      'diagnosedAt': '2025-06-10',
      'status': 'ACTIVE',
    },
  ],
  'medicalHistories': [
    {
      'id': 'm',
      'condition': 'Fracture',
      'diagnosedAt': '2023-01-01',
      'resolvedAt': '2023-04-01',
    },
  ],
  'surgicalHistories': [
    {'id': 's', 'procedureName': 'Appendectomy', 'procedureDate': '2020-02-29'},
  ],
  'familyHistories': [
    {'id': 'f', 'relationship': 'MOTHER', 'condition': 'Diabetes'},
  ],
  'disabilities': [
    {
      'id': 'd',
      'type': 'MOTOR',
      'description': 'Limited mobility',
      'startDate': '2023-01-01',
      'status': 'ACTIVE',
    },
  ],
  'flags': [
    {'id': 'old', 'active': false},
    {'id': 'current', 'active': true},
  ],
  'emergencyProfile': {
    'id': 'e',
    'emergencyCode': 'E001',
    'active': false,
    'bloodGroupVisible': true,
    'allergiesVisible': false,
    'conditionsVisible': true,
    'medicationsVisible': false,
    'emergencyContactVisible': true,
  },
  'emergencyContacts': [
    {
      'id': 'contact',
      'firstName': 'Jane',
      'lastName': 'Smith',
      'relationship': 'SPOUSE',
      'phone': '555-0100',
      'email': null,
    },
  ],
};

class Adapter implements HttpClientAdapter {
  int status = 200;
  Object? body = medicalContract();
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

class Session extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'person1'}),
  );
  void signOut() => state = const SessionState(status: SessionStatus.signedOut);
  void switchUser() => state = const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'person2'}),
  );
}

class PendingRepository implements PatientMedicalRecordRepository {
  final requests = <Completer<PatientMedicalRecord>>[];
  final tokens = <CancelToken?>[];
  @override
  Future<PatientMedicalRecord> fetchMedicalRecord({CancelToken? cancelToken}) {
    tokens.add(cancelToken);
    final pending = Completer<PatientMedicalRecord>();
    requests.add(pending);
    return pending.future;
  }
}

void main() {
  test(
    'clinical contract preserves resolved allergies, history and emergency settings',
    () {
      final record = PatientMedicalRecord.fromJson(medicalContract());
      expect(record.allergies.single.status, 'RESOLVED');
      expect(record.chronicDiseases.single.diagnosisLabel, 'Asthma');
      expect(record.chronicDiseases.single.diagnosedAt, DateTime(2025, 6, 10));
      expect(record.medicalHistories.single.resolvedAt, DateTime(2023, 4, 1));
      expect(
        record.surgicalHistories.single.procedureDate,
        DateTime(2020, 2, 29),
      );
      expect(record.familyHistories.single.relationship, 'MOTHER');
      expect(record.disabilities.single.description, 'Limited mobility');
      expect(record.flags.single.id, 'current');
      expect(record.emergencyProfile?.active, false);
      expect(record.emergencyProfile?.bloodGroupVisible, true);
      expect(record.emergencyContacts.single.displayName, 'Jane Smith');
    },
  );
  test(
    'missing collections and invalid emergency settings are not interpreted as empty',
    () {
      final partial = medicalContract()..remove('chronicDiseases');
      expect(
        () => PatientMedicalRecord.fromJson(partial),
        throwsFormatException,
      );
      final invalid = medicalContract();
      invalid['emergencyProfile']['active'] = 'false';
      expect(
        () => PatientMedicalRecord.fromJson(invalid),
        throwsFormatException,
      );
      final invalidDate = medicalContract();
      invalidDate['surgicalHistories'][0]['procedureDate'] = '2026-02-31';
      expect(
        () => PatientMedicalRecord.fromJson(invalidDate),
        throwsFormatException,
      );
      final noProfile = medicalContract()..['emergencyProfile'] = null;
      expect(PatientMedicalRecord.fromJson(noProfile).emergencyProfile, isNull);
    },
  );
  test(
    'self endpoint has no patient query and maps denied missing or malformed records',
    () async {
      final adapter = Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1/'))
        ..httpClientAdapter = adapter;
      final repository = DioPatientMedicalRecordRepository(dio);
      expect(
        (await repository.fetchMedicalRecord()).patient.patientNumber,
        'P001',
      );
      expect(adapter.request?.uri.path, '/api/v1/patients/me/medical-record');
      expect(adapter.request?.queryParameters, isEmpty);
      for (final status in [401, 403, 404, 500]) {
        adapter.status = status;
        await expectLater(
          repository.fetchMedicalRecord(),
          throwsA(
            isA<AppException>().having((e) => e.statusCode, 'status', status),
          ),
        );
      }
      adapter.status = 200;
      adapter.body = {'patient': null};
      await expectLater(
        repository.fetchMedicalRecord(),
        throwsA(isA<AppException>()),
      );
      dio.close();
    },
  );
  test('logout cancels retrieval and discards late clinical data', () async {
    final session = Session();
    final repository = PendingRepository();
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(() => session),
        patientMedicalRecordRepositoryProvider.overrideWithValue(repository),
      ],
    );
    final subscription = container.listen(
      patientMedicalRecordProvider,
      (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);
    session.signOut();
    expect(await container.read(patientMedicalRecordProvider.future), isNull);
    expect(repository.tokens.single?.isCancelled, true);
    repository.requests.single.complete(
      PatientMedicalRecord.fromJson(medicalContract()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(patientMedicalRecordProvider).value, isNull);
    subscription.close();
    container.dispose();
  });
  test(
    'account switch cancels previous request and rejects a mismatched identity',
    () async {
      final session = Session();
      final repository = PendingRepository();
      final container = ProviderContainer(
        overrides: [
          sessionControllerProvider.overrideWith(() => session),
          patientMedicalRecordRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final subscription = container.listen(
        patientMedicalRecordProvider,
        (_, _) {},
      );
      await Future<void>.delayed(Duration.zero);
      session.switchUser();
      final pending = container.read(patientMedicalRecordProvider.future);
      expect(repository.tokens.first?.isCancelled, true);
      repository.requests.first.complete(
        PatientMedicalRecord.fromJson(medicalContract()),
      );
      repository.requests.last.complete(
        PatientMedicalRecord.fromJson(medicalContract()),
      );
      await expectLater(pending, throwsFormatException);
      expect(container.read(patientMedicalRecordProvider).hasError, true);
      subscription.close();
      container.dispose();
    },
  );
}
