import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';
import '../data/prescription_repository.dart';
import '../domain/prescription.dart';

/// Patient-visible clinical data is held only while the authenticated view lives.
final prescriptionsProvider = FutureProvider.autoDispose
    .family<PrescriptionPage?, PrescriptionListQuery>((ref, query) async {
      if (!_authenticated(ref)) return null;
      final token = _cancelOnDispose(ref);
      final result = await ref
          .watch(prescriptionRepositoryProvider)
          .list(query, cancelToken: token);
      _ensureCurrent(ref, token);
      return result;
    }, retry: (_, _) => null);

final prescriptionDetailProvider = FutureProvider.autoDispose
    .family<PrescriptionDetail?, String>((ref, id) async {
      if (!_authenticated(ref)) return null;
      final token = _cancelOnDispose(ref);
      final result = await ref
          .watch(prescriptionRepositoryProvider)
          .detail(id, cancelToken: token);
      _ensureCurrent(ref, token);
      return result;
    }, retry: (_, _) => null);

bool _authenticated(Ref ref) =>
    ref
        .watch(
          sessionControllerProvider.select(
            (session) => (session.status, session.profile?.id),
          ),
        )
        .$1 ==
    SessionStatus.authenticated;

CancelToken _cancelOnDispose(Ref ref) {
  final token = CancelToken();
  ref.onDispose(() => token.cancel('Session or screen changed'));
  return token;
}

void _ensureCurrent(Ref ref, CancelToken token) {
  if (!ref.mounted || token.isCancelled) {
    throw const AppException(
      kind: AppErrorKind.cancelled,
      message: 'La session a changé.',
    );
  }
}
