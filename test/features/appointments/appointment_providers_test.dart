import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/appointments/application/appointment_providers.dart';
import 'package:healthysv2/features/appointments/data/appointment_repository.dart';
import 'package:healthysv2/features/appointments/domain/appointment.dart';
import 'appointment_fixtures.dart';

class TestSession extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'person-1'}),
  );
  void signOut() => state = const SessionState(status: SessionStatus.signedOut);
  void switchUser() => state = const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'person-2'}),
  );
}

class Repository implements AppointmentRepository {
  final listPending = <Completer<AppointmentPage>>[];
  final listTokens = <CancelToken?>[];
  final mutationPending = <Completer<AppointmentSummary>>[];
  final mutationTokens = <CancelToken?>[];
  bool holdLists = false;
  bool holdMutations = false;
  bool failMutations = false;
  int lists = 0;
  int mutations = 0;
  @override
  Future<AppointmentPage> list(
    AppointmentListQuery query, {
    CancelToken? cancelToken,
  }) {
    lists++;
    listTokens.add(cancelToken);
    if (!holdLists) return Future.value(page());
    final pending = Completer<AppointmentPage>();
    listPending.add(pending);
    return pending.future;
  }

  Future<AppointmentSummary> mutate(CancelToken? token) {
    mutations++;
    mutationTokens.add(token);
    if (failMutations) {
      return Future.error(
        const AppException(
          kind: AppErrorKind.validation,
          message: 'Créneau indisponible',
          statusCode: 409,
        ),
      );
    }
    if (!holdMutations) return Future.value(appointment());
    final pending = Completer<AppointmentSummary>();
    mutationPending.add(pending);
    return pending.future;
  }

  @override
  Future<AppointmentSummary> create({
    required String organizationId,
    required String professionalId,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    String? reason,
    CancelToken? cancelToken,
  }) => mutate(cancelToken);
  @override
  Future<AppointmentSummary> cancel(
    String id, {
    String? reason,
    CancelToken? cancelToken,
  }) => mutate(cancelToken);
  @override
  Future<AppointmentSummary> reschedule(
    String id, {
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    String? reason,
    CancelToken? cancelToken,
  }) => mutate(cancelToken);
  @override
  Future<AppointmentSummary> detail(
    String id, {
    CancelToken? cancelToken,
  }) async => appointment(id: id);
  @override
  Future<BookingOptions> bookingOptions({CancelToken? cancelToken}) async =>
      const BookingOptions(organizations: [], professionals: []);
  @override
  Future<List<AppointmentSlot>> availability(
    AvailabilityQuery query, {
    CancelToken? cancelToken,
  }) async => [];
}

void main() {
  const query = AppointmentListQuery(view: AppointmentView.upcoming);
  late TestSession session;
  late Repository repository;
  late ProviderContainer container;
  setUp(() {
    session = TestSession();
    repository = Repository();
    container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(() => session),
        appointmentRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });
  tearDown(() => container.dispose());

  test('logout cancels list request and discards late patient data', () async {
    repository.holdLists = true;
    final subscription = container.listen(
      appointmentsProvider(query),
      (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);
    session.signOut();
    expect(await container.read(appointmentsProvider(query).future), isNull);
    expect(repository.listTokens.single?.isCancelled, true);
    repository.listPending.single.complete(page());
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appointmentsProvider(query)).value, isNull);
    subscription.close();
  });

  test(
    'account switch cancels old list before displaying the new session list',
    () async {
      repository.holdLists = true;
      final subscription = container.listen(
        appointmentsProvider(query),
        (_, _) {},
      );
      await Future<void>.delayed(Duration.zero);
      session.switchUser();
      final latest = container.read(appointmentsProvider(query).future);
      expect(repository.listTokens.first?.isCancelled, true);
      repository.listPending.first.complete(page());
      repository.listPending.last.complete(
        const AppointmentPage(
          content: [],
          number: 0,
          size: 20,
          totalElements: 0,
          totalPages: 0,
          first: true,
          last: true,
        ),
      );
      expect((await latest)?.content, isEmpty);
      subscription.close();
    },
  );

  test(
    'successful explicit mutation refreshes lists and duplicate taps are rejected',
    () async {
      repository.holdMutations = true;
      final listSubscription = container.listen(
        appointmentsProvider(query),
        (_, _) {},
      );
      await container.read(appointmentsProvider(query).future);
      final actionsSubscription = container.listen(
        appointmentActionsProvider,
        (_, _) {},
      );
      final actions = container.read(appointmentActionsProvider.notifier);
      final pending = actions.cancel('appointment-1');
      expect(container.read(appointmentActionsProvider).isLoading, true);
      await expectLater(
        actions.cancel('appointment-1'),
        throwsA(isA<AppException>()),
      );
      expect(repository.mutations, 1);
      repository.mutationPending.single.complete(appointment());
      await pending;
      await container.read(appointmentsProvider(query).future);
      expect(repository.lists, 2);
      expect(container.read(appointmentActionsProvider).hasError, false);
      actionsSubscription.close();
      listSubscription.close();
    },
  );

  test(
    'logout cancels a mutation and late success cannot enter the signed-out UI',
    () async {
      repository.holdMutations = true;
      final subscription = container.listen(
        appointmentActionsProvider,
        (_, _) {},
      );
      final pending = container
          .read(appointmentActionsProvider.notifier)
          .cancel('appointment-1');
      final assertion = expectLater(
        pending,
        throwsA(
          isA<AppException>().having(
            (error) => error.kind,
            'kind',
            AppErrorKind.cancelled,
          ),
        ),
      );
      session.signOut();
      expect(container.read(appointmentActionsProvider).isLoading, false);
      expect(repository.mutationTokens.single?.isCancelled, true);
      repository.mutationPending.single.complete(appointment());
      await assertion;
      expect(repository.mutations, 1);
      expect(container.read(appointmentActionsProvider).hasError, false);
      subscription.close();
    },
  );

  test(
    'mutation failure is exposed once and needs another user action to retry',
    () async {
      repository.failMutations = true;
      final subscription = container.listen(
        appointmentActionsProvider,
        (_, _) {},
      );
      final actions = container.read(appointmentActionsProvider.notifier);
      await expectLater(
        actions.cancel('appointment-1'),
        throwsA(isA<AppException>()),
      );
      expect(container.read(appointmentActionsProvider).hasError, true);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(repository.mutations, 1);
      repository.failMutations = false;
      await actions.cancel('appointment-1');
      expect(repository.mutations, 2);
      subscription.close();
    },
  );

  test(
    'signed-out sessions never request list detail options or availability',
    () async {
      container.read(sessionControllerProvider);
      session.signOut();
      expect(await container.read(appointmentsProvider(query).future), isNull);
      expect(
        await container.read(appointmentDetailProvider('appointment-1').future),
        isNull,
      );
      expect(await container.read(bookingOptionsProvider.future), isNull);
      expect(
        await container.read(
          availabilityProvider(
            AvailabilityQuery(
              organizationId: 'org',
              professionalId: 'pro',
              from: DateTime.utc(2026, 11, 1),
              to: DateTime.utc(2026, 11, 2),
            ),
          ).future,
        ),
        isNull,
      );
      expect(repository.lists, 0);
      await expectLater(
        container
            .read(appointmentActionsProvider.notifier)
            .cancel('appointment-1'),
        throwsA(isA<AppException>()),
      );
      expect(repository.mutations, 0);
    },
  );
}
