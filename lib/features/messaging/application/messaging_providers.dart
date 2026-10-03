import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';
import '../../documents/domain/document.dart';
import '../data/messaging_repository.dart';
import '../data/messaging_socket.dart';
import '../domain/messaging.dart';
export '../data/messaging_socket.dart'
    show MessagingConnectionState, MessagingConnectionStatus;

final conversationsProvider = FutureProvider.autoDispose
    .family<MessagingPage<ConversationSummary>?, MessagingQuery>((
      ref,
      query,
    ) async {
      if (!_authenticated(ref)) {
        return null;
      }
      final token = _cancel(ref);
      final result = await ref
          .watch(messagingRepositoryProvider)
          .conversations(query, cancelToken: token);
      _ensure(ref, token);
      return result;
    }, retry: (_, _) => null);
final conversationDetailProvider = FutureProvider.autoDispose
    .family<ConversationDetail?, String>((ref, id) async {
      if (!_authenticated(ref)) {
        return null;
      }
      final token = _cancel(ref);
      final result = await ref
          .watch(messagingRepositoryProvider)
          .conversation(id, cancelToken: token);
      _ensure(ref, token);
      return result;
    }, retry: (_, _) => null);
final messagesProvider = FutureProvider.autoDispose
    .family<MessagingPage<Message>?, MessagingQuery>((ref, query) async {
      if (!_authenticated(ref)) {
        return null;
      }
      final token = _cancel(ref);
      final result = await ref
          .watch(messagingRepositoryProvider)
          .messages(query, cancelToken: token);
      _ensure(ref, token);
      return result;
    }, retry: (_, _) => null);
final messagingRecipientsProvider =
    FutureProvider.autoDispose<List<MessagingRecipient>?>((ref) async {
      if (!_authenticated(ref)) {
        return null;
      }
      final token = _cancel(ref);
      final result = await ref
          .watch(messagingRepositoryProvider)
          .recipients(cancelToken: token);
      _ensure(ref, token);
      return result;
    }, retry: (_, _) => null);
final messagingAttachmentProvider = FutureProvider.autoDispose
    .family<MessagingAttachment?, MessagingAttachmentQuery>((ref, query) async {
      if (!_authenticated(ref)) {
        return null;
      }
      final token = _cancel(ref);
      final result = await ref
          .watch(messagingRepositoryProvider)
          .attachment(
            query.conversationId,
            query.documentId,
            cancelToken: token,
          );
      _ensure(ref, token);
      return result;
    }, retry: (_, _) => null);
final downloadedMessagingAttachmentProvider = FutureProvider.autoDispose
    .family<DownloadedDocument?, MessagingAttachmentQuery>((ref, query) async {
      if (!_authenticated(ref)) {
        return null;
      }
      final token = _cancel(ref);
      final result = await ref
          .watch(messagingRepositoryProvider)
          .download(query.conversationId, query.documentId, cancelToken: token);
      _ensure(ref, token);
      return result;
    }, retry: (_, _) => null);
final messagingActionsProvider = Provider.autoDispose<MessagingActions>((ref) {
  _authenticated(ref);
  final token = _cancel(ref);
  return MessagingActions(ref, ref.watch(messagingRepositoryProvider), token);
});

class MessagingActions {
  MessagingActions(this.ref, this.repository, this.token);
  final Ref ref;
  final MessagingRepository repository;
  final CancelToken token;
  Future<T> _perform<T>(Future<T> Function() action) async {
    _ensure(ref, token);
    if (!ref.read(sessionControllerProvider).isAuthenticated) {
      throw const AppException(
        kind: AppErrorKind.unauthorized,
        message: 'Session expirée.',
      );
    }
    final result = await action();
    _ensure(ref, token);
    return result;
  }

  Future<Message> send(
    String conversationId,
    String content, {
    List<String> documentIds = const [],
  }) async {
    final result = await _perform(
      () => repository.send(
        conversationId,
        content,
        documentIds: documentIds,
        cancelToken: token,
      ),
    );
    ref.invalidate(messagesProvider);
    ref.invalidate(conversationsProvider);
    return result;
  }

  Future<void> markRead(String messageId) async {
    await _perform(() => repository.markRead(messageId, cancelToken: token));
    ref.invalidate(conversationsProvider);
  }

  Future<ConversationDetail> create(
    String recipientPersonId,
    String subject,
  ) async {
    final result = await _perform(
      () => repository.create(recipientPersonId, subject, cancelToken: token),
    );
    ref.invalidate(conversationsProvider);
    return result;
  }

  Future<MessagingAttachment> upload(
    String conversationId,
    String fileName,
    Uint8List bytes,
  ) => _perform(
    () =>
        repository.upload(conversationId, fileName, bytes, cancelToken: token),
  );
  Future<DownloadedDocument> download(
    String conversationId,
    String documentId,
  ) => _perform(
    () => repository.download(conversationId, documentId, cancelToken: token),
  );
}

final messagingSocketConnectorProvider = Provider<MessagingSocketConnector>(
  (ref) => connectMessagingSocket,
);
final messagingConnectionProvider = NotifierProvider.autoDispose
    .family<MessagingConnectionController, MessagingConnectionState, String>(
      MessagingConnectionController.new,
    );

class MessagingConnectionController extends Notifier<MessagingConnectionState> {
  MessagingConnectionController(this.conversationId);
  final String conversationId;
  MessagingRealtime? _realtime;
  @override
  MessagingConnectionState build() {
    final authenticated = _authenticated(ref);
    if (!authenticated) {
      return const MessagingConnectionState(
        MessagingConnectionStatus.disconnected,
      );
    }
    final session = ref.read(sessionControllerProvider.notifier);
    final revision = session.revision;
    final person = ref.read(sessionControllerProvider).profile?.id;
    Timer? reconciliation;
    ref.onDispose(() => reconciliation?.cancel());
    final realtime = MessagingRealtime(
      uri: messagingSocketUri(ref.watch(appConfigProvider).apiBaseUrl),
      conversationId: conversationId,
      tokenReader: session.accessToken,
      isCurrent: () =>
          ref.mounted &&
          session.revision == revision &&
          ref.read(sessionControllerProvider).profile?.id == person &&
          ref.read(sessionControllerProvider).isAuthenticated,
      connector: ref.watch(messagingSocketConnectorProvider),
      onState: (status) {
        if (ref.mounted &&
            session.revision == revision &&
            ref.read(sessionControllerProvider).profile?.id == person) {
          state = MessagingConnectionState(status, revision: state.revision);
        }
      },
      onChange: () {
        reconciliation?.cancel();
        reconciliation = Timer(const Duration(milliseconds: 150), () {
          if (ref.mounted &&
              session.revision == revision &&
              ref.read(sessionControllerProvider).profile?.id == person) {
            state = MessagingConnectionState(
              state.status,
              revision: state.revision + 1,
            );
            ref.invalidate(messagesProvider);
            ref.invalidate(conversationsProvider);
          }
        });
      },
    );
    _realtime = realtime;
    ref.onDispose(realtime.dispose);
    unawaited(Future<void>.microtask(realtime.start));
    return const MessagingConnectionState(MessagingConnectionStatus.connecting);
  }

  void reconnect() => _realtime?.reconnect();
  void suspend() => _realtime?.suspend();
  void resume() => _realtime?.resume();
}

bool _authenticated(Ref ref) =>
    ref
        .watch(
          sessionControllerProvider.select(
            (session) => (session.status, session.profile?.id),
          ),
        )
        .$1 ==
    SessionStatus.authenticated;
CancelToken _cancel(Ref ref) {
  final token = CancelToken();
  ref.onDispose(() => token.cancel('Session or screen changed'));
  return token;
}

void _ensure(Ref ref, CancelToken token) {
  if (!ref.mounted || token.isCancelled) {
    throw const AppException(
      kind: AppErrorKind.cancelled,
      message: 'La session a changé.',
    );
  }
}

final messagingListConnectionProvider =
    NotifierProvider.autoDispose<
      MessagingListConnectionController,
      MessagingConnectionState
    >(MessagingListConnectionController.new);

class MessagingListConnectionController
    extends Notifier<MessagingConnectionState> {
  MessagingRealtime? _realtime;
  @override
  MessagingConnectionState build() {
    if (!_authenticated(ref)) {
      return const MessagingConnectionState(
        MessagingConnectionStatus.disconnected,
      );
    }
    final session = ref.read(sessionControllerProvider.notifier);
    final revision = session.revision;
    final person = ref.read(sessionControllerProvider).profile?.id;
    if (person == null) {
      return const MessagingConnectionState(
        MessagingConnectionStatus.disconnected,
      );
    }
    Timer? reconciliation;
    ref.onDispose(() => reconciliation?.cancel());
    final realtime = MessagingRealtime(
      uri: messagingSocketUri(ref.watch(appConfigProvider).apiBaseUrl),
      personId: person,
      tokenReader: session.accessToken,
      isCurrent: () =>
          ref.mounted &&
          session.revision == revision &&
          ref.read(sessionControllerProvider).profile?.id == person &&
          ref.read(sessionControllerProvider).isAuthenticated,
      connector: ref.watch(messagingSocketConnectorProvider),
      onState: (status) {
        if (ref.mounted &&
            session.revision == revision &&
            ref.read(sessionControllerProvider).profile?.id == person) {
          state = MessagingConnectionState(status, revision: state.revision);
        }
      },
      onChange: () {
        reconciliation?.cancel();
        reconciliation = Timer(const Duration(milliseconds: 150), () {
          if (ref.mounted &&
              session.revision == revision &&
              ref.read(sessionControllerProvider).profile?.id == person) {
            state = MessagingConnectionState(
              state.status,
              revision: state.revision + 1,
            );
            ref.invalidate(conversationsProvider);
          }
        });
      },
    );
    _realtime = realtime;
    ref.onDispose(realtime.dispose);
    unawaited(Future<void>.microtask(realtime.start));
    return const MessagingConnectionState(MessagingConnectionStatus.connecting);
  }

  void reconnect() => _realtime?.reconnect();
  void suspend() => _realtime?.suspend();
  void resume() => _realtime?.resume();
}
