import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';
import '../data/document_repository.dart';
import '../domain/document.dart';

final documentsProvider = FutureProvider.autoDispose
    .family<DocumentPage?, DocumentListQuery>((ref, query) async {
      if (!_authenticated(ref)) return null;
      final token = _cancelOnDispose(ref);
      final result = await ref
          .watch(documentRepositoryProvider)
          .list(query, cancelToken: token);
      _ensureCurrent(ref, token);
      return result;
    }, retry: (_, _) => null);

final documentDetailProvider = FutureProvider.autoDispose
    .family<DocumentMetadata?, String>((ref, id) async {
      if (!_authenticated(ref)) return null;
      final token = _cancelOnDispose(ref);
      final result = await ref
          .watch(documentRepositoryProvider)
          .detail(id, cancelToken: token);
      _ensureCurrent(ref, token);
      return result;
    }, retry: (_, _) => null);

/// Invoke only following an explicit patient action; metadata views never fetch
/// file content. Binary clinical data is not persisted by this provider.
final downloadedDocumentProvider = FutureProvider.autoDispose
    .family<DownloadedDocument?, String>((ref, id) async {
      if (!_authenticated(ref)) return null;
      final token = _cancelOnDispose(ref);
      final result = await ref
          .watch(documentRepositoryProvider)
          .download(id, cancelToken: token);
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
  ref.onDispose(() {
    if (!token.isCancelled) token.cancel('Session or screen changed');
  });
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
