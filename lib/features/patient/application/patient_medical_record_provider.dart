import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';
import '../data/patient_medical_record_repository.dart';
import '../domain/patient_medical_record.dart';

/// Clinical information exists only for the current authenticated session.
final patientMedicalRecordProvider =
    FutureProvider.autoDispose<PatientMedicalRecord?>((ref) async {
      final session = ref.watch(
        sessionControllerProvider.select((s) => (s.status, s.profile?.id)),
      );
      if (session.$1 != SessionStatus.authenticated) return null;
      final cancelToken = CancelToken();
      ref.onDispose(() => cancelToken.cancel('Session or screen changed'));
      final record = await ref
          .watch(patientMedicalRecordRepositoryProvider)
          .fetchMedicalRecord(cancelToken: cancelToken);
      if (session.$2 != null && record.patient.personId != session.$2) {
        throw const FormatException(
          'Clinical record belongs to another identity',
        );
      }
      return record;
    }, retry: (_, _) => null);
