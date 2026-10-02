import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';
import '../data/consultation_repository.dart';
import '../domain/consultation.dart';

/// Patient-visible clinical data is held only while the authenticated view lives.
final consultationsProvider = FutureProvider.autoDispose
    .family<ConsultationPage?, ConsultationListQuery>((ref, query) async {
      if (!_authenticated(ref)) return null;
      final token = _cancelOnDispose(ref);
      final result = await ref
          .watch(consultationRepositoryProvider)
          .list(query, cancelToken: token);
      _ensureCurrent(ref, token);
      return result;
    }, retry: (_, _) => null);

final consultationDetailProvider = FutureProvider.autoDispose
    .family<ConsultationDetail?, String>((ref, id) async {
      if (!_authenticated(ref)) return null;
      final token = _cancelOnDispose(ref);
      final result = await ref
          .watch(consultationRepositoryProvider)
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
