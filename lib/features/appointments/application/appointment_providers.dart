import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment.dart';

// Auto-dispose and session dependencies ensure that patient data is neither
// persisted nor reused after sign-out/account changes. Disable Riverpod retry.
final appointmentsProvider = FutureProvider.autoDispose
    .family<AppointmentPage?, AppointmentListQuery>((ref, query) async {
      if (!_authenticated(ref)) return null;
      final token = _cancelOnDispose(ref);
      final result = await ref
          .watch(appointmentRepositoryProvider)
          .list(query, cancelToken: token);
      _ensureCurrent(ref, token);
      return result;
    }, retry: (_, _) => null);

final appointmentDetailProvider = FutureProvider.autoDispose
    .family<AppointmentSummary?, String>((ref, id) async {
      if (!_authenticated(ref)) return null;
      final token = _cancelOnDispose(ref);
      final result = await ref
          .watch(appointmentRepositoryProvider)
          .detail(id, cancelToken: token);
      _ensureCurrent(ref, token);
      return result;
    }, retry: (_, _) => null);

final bookingOptionsProvider = FutureProvider.autoDispose<BookingOptions?>((
  ref,
) async {
  if (!_authenticated(ref)) return null;
  final token = _cancelOnDispose(ref);
  final result = await ref
      .watch(appointmentRepositoryProvider)
      .bookingOptions(cancelToken: token);
  _ensureCurrent(ref, token);
  return result;
}, retry: (_, _) => null);

final availabilityProvider = FutureProvider.autoDispose
    .family<List<AppointmentSlot>?, AvailabilityQuery>((ref, query) async {
      if (!_authenticated(ref)) return null;
      final token = _cancelOnDispose(ref);
      final result = await ref
          .watch(appointmentRepositoryProvider)
          .availability(query, cancelToken: token);
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
  if (!ref.mounted || token.isCancelled) throw _sessionChanged;
}

const _sessionChanged = AppException(
  kind: AppErrorKind.cancelled,
  message: 'La session a changé.',
);

final appointmentActionsProvider =
    NotifierProvider.autoDispose<AppointmentActions, AsyncValue<void>>(
      AppointmentActions.new,
    );

/// Mutations execute once per deliberate UI action, never from build/listeners.
class AppointmentActions extends Notifier<AsyncValue<void>> {
  int _epoch = 0;
  CancelToken? _pending;

  @override
  AsyncValue<void> build() {
    ref.watch(
      sessionControllerProvider.select((s) => (s.status, s.profile?.id)),
    );
    _epoch++;
    _pending?.cancel('Session changed');
    _pending = null;
    ref.onDispose(() {
      _epoch++;
      _pending?.cancel('Session or screen changed');
    });
    return const AsyncData(null);
  }

  Future<AppointmentSummary> create({
    required String organizationId,
    required String professionalId,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    String? reason,
  }) => _run(
    (repository, token) => repository.create(
      organizationId: organizationId,
      professionalId: professionalId,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      reason: reason,
      cancelToken: token,
    ),
  );

  Future<AppointmentSummary> cancel(String id, {String? reason}) => _run(
    (repository, token) =>
        repository.cancel(id, reason: reason, cancelToken: token),
  );

  Future<AppointmentSummary> reschedule(
    String id, {
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    String? reason,
  }) => _run(
    (repository, token) => repository.reschedule(
      id,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      reason: reason,
      cancelToken: token,
    ),
  );

  Future<AppointmentSummary> _run(
    Future<AppointmentSummary> Function(
      AppointmentRepository repository,
      CancelToken token,
    )
    action,
  ) async {
    if (!ref.read(sessionControllerProvider).isAuthenticated) {
      throw _sessionChanged;
    }
    // Prevent duplicate taps while a mutation is in flight.
    if (state.isLoading) {
      throw const AppException(
        kind: AppErrorKind.validation,
        message: 'Une demande est déjà en cours.',
      );
    }
    final epoch = _epoch;
    final token = CancelToken();
    _pending = token;
    final repository = ref.read(appointmentRepositoryProvider);
    state = const AsyncLoading();
    try {
      final result = await action(repository, token);
      if (!_active(epoch, token)) throw _sessionChanged;
      state = const AsyncData(null);
      ref.invalidate(appointmentsProvider);
      ref.invalidate(appointmentDetailProvider);
      ref.invalidate(availabilityProvider);
      return result;
    } catch (error, stack) {
      if (!_active(epoch, token)) throw _sessionChanged;
      state = AsyncError(error, stack);
      rethrow;
    } finally {
      if (identical(_pending, token)) _pending = null;
    }
  }

  bool _active(int epoch, CancelToken token) =>
      ref.mounted &&
      epoch == _epoch &&
      !token.isCancelled &&
      ref.read(sessionControllerProvider).isAuthenticated;
}
