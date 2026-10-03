import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';
import '../data/notification_repository.dart';
import '../domain/notifications.dart';

bool notificationAuthenticated(Ref ref) =>
    ref
        .watch(
          sessionControllerProvider.select(
            (session) => (session.status, session.profile?.id),
          ),
        )
        .$1 ==
    SessionStatus.authenticated;
CancelToken notificationCancellation(Ref ref) {
  final token = CancelToken();
  ref.onDispose(() => token.cancel('Session changed'));
  return token;
}

void notificationEnsure(Ref ref, CancelToken token) {
  if (!ref.mounted ||
      token.isCancelled ||
      !ref.read(sessionControllerProvider).isAuthenticated) {
    throw const AppException(
      kind: AppErrorKind.cancelled,
      message: 'La session a changé.',
    );
  }
}

final notificationsProvider = FutureProvider.autoDispose
    .family<NotificationPage?, NotificationQuery>((ref, query) async {
      if (!notificationAuthenticated(ref)) {
        return null;
      }
      final token = notificationCancellation(ref);
      final result = await ref
          .watch(notificationRepositoryProvider)
          .list(query, cancelToken: token);
      notificationEnsure(ref, token);
      return result;
    }, retry: (_, _) => null);
final notificationDetailProvider = FutureProvider.autoDispose
    .family<HealthysNotification?, String>((ref, id) async {
      if (!notificationAuthenticated(ref)) {
        return null;
      }
      final token = notificationCancellation(ref);
      final result = await ref
          .watch(notificationRepositoryProvider)
          .detail(id, cancelToken: token);
      notificationEnsure(ref, token);
      return result;
    }, retry: (_, _) => null);
final notificationUnreadCountProvider = FutureProvider.autoDispose<int?>((
  ref,
) async {
  if (!notificationAuthenticated(ref)) {
    return null;
  }
  final token = notificationCancellation(ref);
  final result = await ref
      .watch(notificationRepositoryProvider)
      .unreadCount(cancelToken: token);
  notificationEnsure(ref, token);
  return result;
}, retry: (_, _) => null);
final notificationPreferencesProvider =
    FutureProvider.autoDispose<NotificationPreferences?>((ref) async {
      if (!notificationAuthenticated(ref)) {
        return null;
      }
      final token = notificationCancellation(ref);
      final result = await ref
          .watch(notificationRepositoryProvider)
          .preferences(cancelToken: token);
      notificationEnsure(ref, token);
      return result;
    }, retry: (_, _) => null);
final notificationActionsProvider = Provider<NotificationActions>((ref) {
  notificationAuthenticated(ref);
  return NotificationActions(
    ref,
    ref.watch(notificationRepositoryProvider),
    notificationCancellation(ref),
  );
});

class NotificationActions {
  NotificationActions(this.ref, this.repository, this.token)
    : personId = ref.read(sessionControllerProvider).profile?.id,
      revision = ref.read(sessionControllerProvider.notifier).revision;
  final String? personId;
  final int revision;
  final Ref ref;
  final NotificationRepository repository;
  final CancelToken token;
  Future<T> _perform<T>(Future<T> Function() operation) async {
    _ensure();
    final result = await operation();
    _ensure();
    return result;
  }

  void _ensure() {
    notificationEnsure(ref, token);
    if (ref.read(sessionControllerProvider).profile?.id != personId ||
        ref.read(sessionControllerProvider.notifier).revision != revision) {
      throw const AppException(
        kind: AppErrorKind.cancelled,
        message: 'La session a changé.',
      );
    }
  }

  void _refresh() {
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationUnreadCountProvider);
    ref.invalidate(notificationDetailProvider);
  }

  Future<void> markRead(String id) async {
    await _perform(() => repository.markRead(id, cancelToken: token));
    _refresh();
  }

  Future<void> markAllRead() async {
    await _perform(() => repository.markAllRead(cancelToken: token));
    _refresh();
  }

  Future<NotificationPreferences> savePreferences(
    NotificationPreferences preferences,
  ) async {
    final result = await _perform(
      () => repository.savePreferences(preferences, cancelToken: token),
    );
    ref.invalidate(notificationPreferencesProvider);
    return result;
  }

  Future<String> open(String id) async {
    final notification = await _perform(
      () => repository.detail(id, cancelToken: token),
    );
    await _perform(() => repository.markRead(id, cancelToken: token));
    _refresh();
    return notificationDestination(notification);
  }
}
