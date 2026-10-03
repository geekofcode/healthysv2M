import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';
import '../data/maternal_child_repository.dart';
import '../domain/maternal_child.dart';

final pregnanciesProvider = FutureProvider.autoDispose
    .family<MaternalPage<PregnancySummary>?, MaternalChildListQuery>((
      ref,
      value,
    ) async {
      if (!_authenticated(ref)) return null;
      final token = _cancelOnDispose(ref);
      final result = await ref
          .watch(maternalChildRepositoryProvider)
          .pregnancies(value, cancelToken: token);
      _ensureCurrent(ref, token);
      return result;
    }, retry: (_, _) => null);

final childrenProvider = FutureProvider.autoDispose
    .family<MaternalPage<ChildSummary>?, MaternalChildListQuery>((
      ref,
      value,
    ) async {
      if (!_authenticated(ref)) return null;
      final token = _cancelOnDispose(ref);
      final result = await ref
          .watch(maternalChildRepositoryProvider)
          .children(value, cancelToken: token);
      _ensureCurrent(ref, token);
      return result;
    }, retry: (_, _) => null);

final pregnancyDetailProvider = FutureProvider.autoDispose
    .family<PregnancyDetail?, String>((ref, value) async {
      if (!_authenticated(ref)) return null;
      final token = _cancelOnDispose(ref);
      final result = await ref
          .watch(maternalChildRepositoryProvider)
          .pregnancy(value, cancelToken: token);
      _ensureCurrent(ref, token);
      return result;
    }, retry: (_, _) => null);

final childDetailProvider = FutureProvider.autoDispose
    .family<ChildDetail?, String>((ref, value) async {
      if (!_authenticated(ref)) return null;
      final token = _cancelOnDispose(ref);
      final result = await ref
          .watch(maternalChildRepositoryProvider)
          .child(value, cancelToken: token);
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
