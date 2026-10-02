import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/patient_medical_record.dart';

abstract interface class PatientMedicalRecordRepository {
  Future<PatientMedicalRecord> fetchMedicalRecord({CancelToken? cancelToken});
}

class DioPatientMedicalRecordRepository
    implements PatientMedicalRecordRepository {
  DioPatientMedicalRecordRepository(this.dio);
  final Dio dio;
  @override
  Future<PatientMedicalRecord> fetchMedicalRecord({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        'patients/me/medical-record',
        cancelToken: cancelToken,
      );
      if (response.data == null) {
        throw const FormatException('Empty clinical record');
      }
      return PatientMedicalRecord.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.error case final AppException mapped) throw mapped;
      throw AppException.fromDio(error);
    } on FormatException {
      throw const AppException(
        kind: AppErrorKind.unknown,
        message: 'Le dossier médical est indisponible.',
      );
    } on TypeError {
      throw const AppException(
        kind: AppErrorKind.unknown,
        message: 'Le dossier médical est indisponible.',
      );
    }
  }
}

final patientMedicalRecordRepositoryProvider =
    Provider<PatientMedicalRecordRepository>(
      (ref) => DioPatientMedicalRecordRepository(ref.watch(dioProvider)),
    );
