import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';
import '../data/patient_repository.dart';
import '../domain/patient_dashboard.dart';

final patientClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Medical data is scoped to the current identity, cancelled on disposal and
/// never persisted. A signed-out session yields no cached patient information.
final patientDashboardProvider = FutureProvider.autoDispose<PatientDashboard?>((
  ref,
) {
  final session = ref.watch(
    sessionControllerProvider.select((s) => (s.status, s.profile?.id)),
  );
  if (session.$1 != SessionStatus.authenticated) return null;
  final cancellation = CancelToken();
  ref.onDispose(() => cancellation.cancel('Session or screen changed'));
  return ref
      .watch(patientRepositoryProvider)
      .fetchDashboard(cancelToken: cancellation);
}, retry: (_, _) => null);
