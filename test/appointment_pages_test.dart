import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/app/healthys_app.dart';
import 'package:healthysv2/app/router/app_router.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/appointments/data/appointment_repository.dart';
import 'package:healthysv2/features/appointments/domain/appointment.dart';
import 'package:healthysv2/features/appointments/presentation/appointment_labels.dart';
import 'package:healthysv2/features/patient/application/patient_dashboard_provider.dart';

const appointmentId = '00000000-0000-0000-0000-000000000001';
final start = DateTime.now().toUtc().add(const Duration(hours: 2));
AppointmentSummary summary({String status = 'SCHEDULED', DateTime? at}) =>
    AppointmentSummary(
      id: appointmentId,
      appointmentNumber: 'APT-1',
      patientId: 'p1',
      professionalId: 'doctor-id-not-for-display',
      professionalName: 'Dr Ada Lovelace',
      organizationId: 'org-id-not-for-display',
      organizationName: 'Clinic Québec',
      type: 'CONSULTATION',
      scheduledStart: at ?? start,
      scheduledEnd: (at ?? start).add(const Duration(minutes: 30)),
      reason: 'Follow-up',
      status: status,
      version: 1,
      canCancel: status == 'SCHEDULED',
      canReschedule: status == 'SCHEDULED',
    );
const options = BookingOptions(
  organizations: [
    BookingOrganization(id: 'org-id-not-for-display', name: 'Clinic Québec'),
  ],
  professionals: [
    BookingProfessional(
      id: 'doctor-id-not-for-display',
      organizationId: 'org-id-not-for-display',
      name: 'Dr Ada Lovelace',
      professionalType: 'DOCTOR',
    ),
  ],
);

class FakeAppointments implements AppointmentRepository {
  AppointmentSummary current = summary();
  BookingOptions availableOptions = options;
  List<AppointmentSlot> slots = [
    AppointmentSlot(
      scheduledStart: start.add(const Duration(hours: 1)),
      scheduledEnd: start.add(const Duration(hours: 1, minutes: 30)),
    ),
  ];
  int creates = 0, cancels = 0, reschedules = 0;
  Object? mutationError;
  Object? listError;
  Completer<AppointmentSummary>? pendingMutation;
  final List<AppointmentListQuery> queries = [];
  final List<AvailabilityQuery> availabilityQueries = [];
  String? submittedOrganization, submittedProfessional, submittedReason;
  DateTime? submittedStart;
  @override
  Future<AppointmentPage> list(
    AppointmentListQuery query, {
    CancelToken? cancelToken,
  }) async {
    queries.add(query);
    if (listError != null) throw listError!;
    return AppointmentPage(
      content: query.view == AppointmentView.past ? [] : [current],
      number: query.page,
      size: 20,
      totalElements: 21,
      totalPages: 2,
      first: query.page == 0,
      last: query.page == 1,
    );
  }

  @override
  Future<AppointmentSummary> detail(
    String id, {
    CancelToken? cancelToken,
  }) async => current;
  @override
  Future<BookingOptions> bookingOptions({CancelToken? cancelToken}) async =>
      availableOptions;
  @override
  Future<List<AppointmentSlot>> availability(
    AvailabilityQuery query, {
    CancelToken? cancelToken,
  }) async {
    availabilityQueries.add(query);
    return slots;
  }

  @override
  Future<AppointmentSummary> create({
    required String organizationId,
    required String professionalId,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    String? reason,
    CancelToken? cancelToken,
  }) async {
    creates++;
    submittedOrganization = organizationId;
    submittedProfessional = professionalId;
    submittedStart = scheduledStart;
    submittedReason = reason;
    if (mutationError != null) throw mutationError!;
    if (pendingMutation != null) return pendingMutation!.future;
    return current = summary(at: scheduledStart);
  }

  @override
  Future<AppointmentSummary> cancel(
    String id, {
    String? reason,
    CancelToken? cancelToken,
  }) async {
    cancels++;
    if (mutationError != null) throw mutationError!;
    return current = summary(status: 'CANCELLED');
  }

  @override
  Future<AppointmentSummary> reschedule(
    String id, {
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    String? reason,
    CancelToken? cancelToken,
  }) async {
    reschedules++;
    submittedStart = scheduledStart;
    if (mutationError != null) throw mutationError!;
    return current = summary(at: scheduledStart);
  }
}

class TestSession extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'person1'}),
  );
  void markExpired() =>
      state = const SessionState(status: SessionStatus.expired);
}

Future<ProviderContainer> pumpAppointments(
  WidgetTester tester,
  FakeAppointments repository,
  String route, {
  TestSession? session,
  bool french = false,
}) async {
  if (french) {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
  }
  final container = ProviderContainer(
    overrides: [
      sessionControllerProvider.overrideWith(() => session ?? TestSession()),
      appointmentRepositoryProvider.overrideWithValue(repository),
      patientDashboardProvider.overrideWith((ref) async => null),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const HealthysApp()),
  );
  container.read(appRouterProvider).go(route);
  await tester.pumpAndSettle();
  return container;
}

Future<void> chooseBookingSlot(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Clinic Québec').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<String>).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dr Ada Lovelace').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ChoiceChip).first);
  await tester.pumpAndSettle();
}

Future<void> pressVisible(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'safe return paths include only fixed booking routes and valid UUID detail paths',
    () {
      expect(safeReturnPath('/appointments'), '/appointments');
      expect(safeReturnPath('/appointments/new'), '/appointments/new');
      expect(
        safeReturnPath('/appointments/$appointmentId/reschedule'),
        '/appointments/$appointmentId/reschedule',
      );
      expect(
        safeReturnPath('/appointments/$appointmentId'),
        '/appointments/$appointmentId',
      );
      expect(safeReturnPath('/appointments/fake-id'), '/');
      expect(safeReturnPath('//evil.test/appointments'), '/');
    },
  );
  testWidgets('upcoming history pagination show actual names and local times', (
    tester,
  ) async {
    final repository = FakeAppointments();
    await pumpAppointments(tester, repository, '/appointments');
    expect(find.textContaining('Dr Ada Lovelace'), findsOneWidget);
    expect(find.textContaining('org-id-not-for-display'), findsNothing);
    expect(find.text('Page 1 / 2'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.page, 1);
    expect(find.text('Page 2 / 2'), findsOneWidget);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.view, AppointmentView.past);
    expect(repository.queries.last.page, 0);
    expect(find.text('No appointment history.'), findsOneWidget);
  });
  testWidgets('French list error is controlled and retries read request', (
    tester,
  ) async {
    final repository = FakeAppointments()
      ..listError = const AppException(
        kind: AppErrorKind.network,
        message: 'secret',
      );
    await pumpAppointments(tester, repository, '/appointments', french: true);
    expect(find.text('Mes rendez-vous'), findsOneWidget);
    expect(
      find.text('Connexion indisponible. Vérifiez votre réseau.'),
      findsOneWidget,
    );
    expect(find.text('secret'), findsNothing);
    repository.listError = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dr Ada Lovelace'), findsOneWidget);
  });
  testWidgets(
    'booking requires named selections slot and explicit confirmation then opens real detail',
    (tester) async {
      final repository = FakeAppointments();
      await pumpAppointments(tester, repository, '/appointments/new');
      final initialButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Book this slot'),
      );
      expect(initialButton.onPressed, isNull);
      await chooseBookingSlot(tester);
      await tester.enterText(find.byType(TextField), 'Review symptoms');
      await pressVisible(tester, 'Book this slot');
      expect(repository.creates, 0);
      expect(find.text('Confirm booking?'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(repository.creates, 1);
      expect(repository.submittedOrganization, 'org-id-not-for-display');
      expect(repository.submittedProfessional, 'doctor-id-not-for-display');
      expect(repository.submittedReason, 'Review symptoms');
      expect(find.text('Appointment details'), findsOneWidget);
      expect(find.text('APT-1'), findsOneWidget);
    },
  );
  testWidgets('cancel decline makes no request and confirm cancels once', (
    tester,
  ) async {
    final repository = FakeAppointments();
    await pumpAppointments(tester, repository, '/appointments/$appointmentId');
    await pressVisible(tester, 'Cancel appointment');
    expect(repository.cancels, 0);
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    expect(repository.cancels, 0);
    await pressVisible(tester, 'Cancel appointment');
    await tester.tap(find.text('Confirm cancellation'));
    await tester.pumpAndSettle();
    expect(repository.cancels, 1);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Cancel appointment'), findsNothing);
    expect(find.text('Reschedule appointment'), findsNothing);
  });
  testWidgets(
    'reschedule uses real actions invalidation and reaches updated appointment detail',
    (tester) async {
      final repository = FakeAppointments();
      await pumpAppointments(
        tester,
        repository,
        '/appointments/$appointmentId/reschedule',
      );
      expect(find.text('Reason for rescheduling (optional)'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        repository.availabilityQueries.last.excludeAppointmentId,
        appointmentId,
      );
      await tester.tap(find.byType(ChoiceChip).first);
      await tester.pumpAndSettle();
      await pressVisible(tester, 'Confirm new slot');
      expect(repository.reschedules, 0);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(repository.reschedules, 1);
      expect(repository.submittedStart, repository.slots.first.scheduledStart);
      expect(find.text('Appointment details'), findsOneWidget);
      expect(find.text('Confirm new slot'), findsNothing);
    },
  );
  testWidgets(
    'booking conflict clears chosen slot and never retries mutation automatically',
    (tester) async {
      final repository = FakeAppointments()
        ..mutationError = const AppException(
          kind: AppErrorKind.validation,
          statusCode: 409,
          message: 'internal slot data',
        );
      await pumpAppointments(tester, repository, '/appointments/new');
      await chooseBookingSlot(tester);
      await pressVisible(tester, 'Book this slot');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(repository.creates, 1);
      expect(
        find.text(
          'This slot or appointment has changed. Refresh availability before trying again.',
        ),
        findsOneWidget,
      );
      expect(find.text('internal slot data'), findsNothing);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Book this slot'),
      );
      expect(button.onPressed, isNull);
      await tester.pump(const Duration(seconds: 10));
      expect(repository.creates, 1);
    },
  );
  testWidgets(
    'pending booking disables duplicate taps and cannot restore expired session data',
    (tester) async {
      final repository = FakeAppointments()
        ..pendingMutation = Completer<AppointmentSummary>();
      final session = TestSession();
      await pumpAppointments(
        tester,
        repository,
        '/appointments/new',
        session: session,
      );
      await chooseBookingSlot(tester);
      expect(
        repository.availabilityQueries.last.from.isAfter(
          DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
        ),
        isTrue,
      );
      await pressVisible(tester, 'Book this slot');
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.creates, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Book this slot'),
            )
            .onPressed,
        isNull,
      );
      session.markExpired();
      await tester.pumpAndSettle();
      repository.pendingMutation!.complete(summary());
      await tester.pumpAndSettle();
      expect(repository.creates, 1);
      expect(find.text('Appointment details'), findsNothing);
      expect(
        find.text('Your session has expired. Sign in again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty booking options explain organization prerequisite', (
    tester,
  ) async {
    final repository = FakeAppointments()
      ..availableOptions = const BookingOptions(
        organizations: [],
        professionals: [],
      );
    await pumpAppointments(tester, repository, '/appointments/new');
    expect(
      find.text(
        'No organization offers booking for your record. Contact your organization.',
      ),
      findsOneWidget,
    );
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });
  testWidgets(
    'expired session removes appointment data and guards booking route',
    (tester) async {
      final repository = FakeAppointments();
      final session = TestSession();
      await pumpAppointments(
        tester,
        repository,
        '/appointments/$appointmentId',
        session: session,
      );
      expect(find.text('Dr Ada Lovelace'), findsOneWidget);
      session.markExpired();
      await tester.pumpAndSettle();
      expect(find.text('Dr Ada Lovelace'), findsNothing);
      expect(
        find.text('Your session has expired. Sign in again.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'appointment time renderer converts instants to device local time',
    (tester) async {
      final repository = FakeAppointments();
      await pumpAppointments(
        tester,
        repository,
        '/appointments/$appointmentId',
      );
      final context = tester.element(find.text('Appointment details'));
      final formatted = appointmentDateTime(context, start);
      expect(find.text(formatted), findsOneWidget);
      expect(
        formatted,
        contains(
          MaterialLocalizations.of(context).formatMediumDate(start.toLocal()),
        ),
      );
    },
  );
}
