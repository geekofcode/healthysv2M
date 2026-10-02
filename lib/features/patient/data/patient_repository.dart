import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/patient_dashboard.dart';

abstract interface class PatientRepository {
  Future<PatientDashboard> fetchDashboard({CancelToken? cancelToken});
}

class DioPatientRepository implements PatientRepository {
  DioPatientRepository(this.dio);
  final Dio dio;
  @override
  Future<PatientDashboard> fetchDashboard({CancelToken? cancelToken}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        'patients/me/dashboard',
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data == null) throw const FormatException('Empty patient response');
      return PatientDashboard.fromJson(data);
    } on DioException catch (error) {
      if (error.error case final AppException mapped) throw mapped;
      throw AppException.fromDio(error);
    } on FormatException {
      throw const AppException(
        kind: AppErrorKind.unknown,
        message: 'Les données du patient sont indisponibles.',
      );
    } on TypeError {
      throw const AppException(
        kind: AppErrorKind.unknown,
        message: 'Les données du patient sont indisponibles.',
      );
    }
  }
}

final patientRepositoryProvider = Provider<PatientRepository>(
  (ref) => DioPatientRepository(ref.watch(dioProvider)),
);
