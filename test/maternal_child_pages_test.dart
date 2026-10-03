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
import 'package:healthysv2/features/patient/application/patient_dashboard_provider.dart';
import 'package:healthysv2/features/maternal_child/data/maternal_child_repository.dart';
import 'package:healthysv2/features/maternal_child/domain/maternal_child.dart';

const pregnancyId = '00000000-0000-0000-0000-000000000801';
const childId = '00000000-0000-0000-0000-000000000802';
final instant = DateTime.utc(2026, 10, 2, 10);
final samplePregnancy = PregnancySummary(
  id: pregnancyId,
  pregnancyNumber: 'P-801',
  motherPatientId: 'private-mother-id',
  expectedDeliveryDate: '2026-11-04',
  status: 'ACTIVE',
  createdAt: instant,
);
final sampleChild = ChildSummary(
  id: 'different-record-id',
  childPatientId: childId,
  firstName: 'Alice',
  lastName: 'Example',
  dateOfBirth: '2025-05-04',
  sex: 'FEMALE',
  status: 'ACTIVE',
  createdAt: instant,
);

class Session extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'person-1'}),
  );
  @override
  Future<void> expire() async {
    state = const SessionState(status: SessionStatus.expired);
  }
}

class NotebookRepository implements MaternalChildRepository {
  bool empty = false;
  bool delivered = false;
  Object? error;
  int calls = 0;
  String? requestedChild;
  final pregnancyPages = <int>[], childPages = <int>[];
  Completer<ChildDetail>? pending;
  MaternalPage<T> page<T>(List<T> content, int number) => MaternalPage(
    content: content,
    number: number,
    size: 20,
    totalElements: empty ? 0 : 21,
    totalPages: empty ? 0 : 2,
    first: number == 0,
    last: empty || number == 1,
  );
  @override
  Future<MaternalPage<PregnancySummary>> pregnancies(
    MaternalChildListQuery query, {
    CancelToken? cancelToken,
  }) async {
    pregnancyPages.add(query.page);
    if (error != null) {
      throw error!;
    }
    return page(empty ? [] : [samplePregnancy], query.page);
  }

  @override
  Future<MaternalPage<ChildSummary>> children(
    MaternalChildListQuery query, {
    CancelToken? cancelToken,
  }) async {
    childPages.add(query.page);
    if (error != null) {
      throw error!;
    }
    return page(empty ? [] : [sampleChild], query.page);
  }

  @override
  Future<PregnancyDetail> pregnancy(
    String id, {
    CancelToken? cancelToken,
  }) async {
    calls++;
    if (error != null) {
      throw error!;
    }
    return PregnancyDetail(
      pregnancy: samplePregnancy,
      prenatalVisits: empty
          ? []
          : [
              PrenatalVisit(
                id: 'visit',
                visitDate: instant,
                gestationalAgeWeeks: 30,
                weightKg: '70.5',
                systolicPressure: 120,
                diastolicPressure: 80,
                fetalHeartRate: 140,
              ),
            ],
      delivery: !delivered
          ? null
          : BirthSummary(
              id: 'birth',
              deliveryDate: instant,
              deliveryType: 'CESAREAN',
              newborns: [
                const NewbornSummary(
                  id: 'newborn',
                  childPatientId: childId,
                  birthOrder: 1,
                  birthWeightKg: '3.2',
                  birthHeightCm: '50',
                  apgar1: 8,
                  apgar5: 9,
                  status: 'ACTIVE',
                ),
              ],
            ),
    );
  }

  @override
  Future<ChildDetail> child(
    String childPatientId, {
    CancelToken? cancelToken,
  }) async {
    requestedChild = childPatientId;
    calls++;
    if (error != null) {
      throw error!;
    }
    if (pending != null) {
      return pending!.future;
    }
    return record();
  }

  ChildDetail record() => ChildDetail(
    child: sampleChild,
    birth: empty
        ? null
        : ChildBirth(
            deliveryDate: instant,
            deliveryType: 'CESAREAN',
            birthOrder: 1,
            birthWeightKg: '3.2',
            birthHeightCm: '50',
            headCircumferenceCm: '35',
            apgar1: 8,
            apgar5: 9,
            status: 'HEALTHY',
          ),
    vaccinations: empty
        ? []
        : [
            const Vaccination(
              id: 'vaccination',
              vaccineName: 'BCG',
              doseNumber: 1,
              status: 'PLANNED',
              nextDueDate: '2026-11-04',
            ),
          ],
    growthMeasurements: empty
        ? []
        : [
            GrowthMeasurement(
              id: 'measure',
              measuredAt: instant,
              weightKg: '8.5',
              heightCm: '72',
              headCircumferenceCm: '42',
              bmi: '16.4',
            ),
          ],
  );
}

Future<ProviderContainer> pump(
  WidgetTester tester,
  String path, {
  NotebookRepository? repository,
  Session? session,
  bool french = false,
  bool settle = true,
}) async {
  tester.binding.platformDispatcher.localesTestValue = [
    Locale(french ? 'fr' : 'en'),
  ];
  addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
  final container = ProviderContainer(
    overrides: [
      sessionControllerProvider.overrideWith(() => session ?? Session()),
      patientDashboardProvider.overrideWith((ref) async => null),
      maternalChildRepositoryProvider.overrideWithValue(
        repository ?? NotebookRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const HealthysApp()),
  );
  container.read(appRouterProvider).go(path);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  return container;
}

Future<void> reveal(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'notebook return routes allow UUIDs and reject unsafe or unknown destinations',
    () {
      for (final path in [
        '/maternal-child',
        '/maternal-child/pregnancies/$pregnancyId',
        '/maternal-child/children/$childId',
      ]) {
        expect(safeReturnPath(path), path);
      }
      for (final path in [
        '/maternal-child/children/private',
        '/maternal-child/../documents',
        'https://evil.example/maternal-child',
        '/maternal-child/pregnancies/$pregnancyId/other',
      ]) {
        expect(safeReturnPath(path), '/');
      }
    },
  );
  testWidgets(
    'independent history pagination and child navigation uses patient identity',
    (tester) async {
      final repository = NotebookRepository();
      await pump(tester, '/maternal-child', repository: repository);
      expect(find.text('P-801'), findsOneWidget);
      expect(find.text('private-mother-id'), findsNothing);
      await tester.tap(find.text('Next').first);
      await tester.pumpAndSettle();
      expect(repository.pregnancyPages.last, 1);
      expect(repository.childPages.last, 0);
      await reveal(tester, 'Alice Example');
      await tester.tap(find.text('Alice Example'));
      await tester.pumpAndSettle();
      expect(repository.requestedChild, childId);
      expect(find.text('Child identity'), findsOneWidget);
    },
  );
  testWidgets(
    'French prenatal follow-up displays measured units and absent birth',
    (tester) async {
      await pump(
        tester,
        '/maternal-child/pregnancies/$pregnancyId',
        french: true,
      );
      expect(find.text('En cours'), findsOneWidget);
      await reveal(tester, 'Âge gestationnel');
      expect(find.text('30 semaines'), findsOneWidget);
      await reveal(tester, 'Poids');
      expect(find.text('70.5 kg'), findsOneWidget);
      await reveal(tester, 'Pression systolique');
      expect(find.text('120 mmHg'), findsOneWidget);
      await reveal(tester, 'Pression diastolique');
      expect(find.text('80 mmHg'), findsOneWidget);
      await reveal(tester, 'Fréquence cardiaque fœtale');
      expect(find.text('140 bpm'), findsOneWidget);
      await reveal(tester, 'Aucune naissance enregistrée.');
    },
  );
  testWidgets('mother pregnancy includes delivery and newborn measurements', (
    tester,
  ) async {
    await pump(
      tester,
      '/maternal-child/pregnancies/$pregnancyId',
      repository: NotebookRepository()..delivered = true,
    );
    await reveal(tester, 'Delivery');
    expect(find.text('Cesarean'), findsOneWidget);
    await reveal(tester, 'Birth weight');
    expect(find.text('3.2 kg'), findsOneWidget);
    await reveal(tester, 'Apgar at 5 minutes');
    expect(find.text('9'), findsOneWidget);
    expect(find.text(childId), findsNothing);
  });
  testWidgets(
    'child birth vaccination schedule and recorded growth stay distinct',
    (tester) async {
      await pump(tester, '/maternal-child/children/$childId');
      await reveal(tester, 'Birth weight');
      expect(find.text('3.2 kg'), findsOneWidget);
      await reveal(tester, 'Apgar at 1 minute');
      expect(find.text('8'), findsOneWidget);
      await reveal(tester, 'BCG');
      expect(find.text('Planned'), findsOneWidget);
      await reveal(tester, 'Administered');
      expect(find.text('Not provided'), findsWidgets);
      await reveal(tester, 'Next due date');
      await reveal(tester, 'Growth');
      await reveal(tester, 'Length / height');
      expect(find.text('72 cm'), findsOneWidget);
      await reveal(tester, 'Recorded BMI');
      expect(find.text('16.4 kg/m²'), findsOneWidget);
      expect(find.textContaining('percentile'), findsNothing);
    },
  );
  testWidgets('French empty notebook and child sections are explicit', (
    tester,
  ) async {
    await pump(
      tester,
      '/maternal-child',
      repository: NotebookRepository()..empty = true,
      french: true,
    );
    expect(find.text('Aucune grossesse enregistrée.'), findsOneWidget);
    expect(find.text('Aucun carnet enfant accessible.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pump(
      tester,
      '/maternal-child/children/$childId',
      repository: NotebookRepository()..empty = true,
      french: true,
    );
    await reveal(tester, 'Aucune vaccination enregistrée.');
    await reveal(tester, 'Aucune mesure de croissance enregistrée.');
  });
  testWidgets('denied read sanitizes private error and supports manual retry', (
    tester,
  ) async {
    final repository = NotebookRepository()
      ..error = const AppException(
        kind: AppErrorKind.forbidden,
        statusCode: 403,
        message: 'private medical note',
      );
    await pump(
      tester,
      '/maternal-child/pregnancies/$pregnancyId',
      repository: repository,
    );
    expect(find.text('private medical note'), findsNothing);
    expect(repository.calls, 1);
    repository.error = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.text('P-801'), findsOneWidget);
  });
  testWidgets('missing child notebook renders controlled unavailable state', (
    tester,
  ) async {
    await pump(
      tester,
      '/maternal-child/children/$childId',
      repository: NotebookRepository()
        ..error = const AppException(
          kind: AppErrorKind.unknown,
          statusCode: 404,
          message: 'private',
        ),
    );
    expect(
      find.text('This child notebook could not be found or is unavailable.'),
      findsOneWidget,
    );
  });
  testWidgets('session expiry removes pending child data and guards route', (
    tester,
  ) async {
    final repository = NotebookRepository()..pending = Completer<ChildDetail>();
    final session = Session();
    await pump(
      tester,
      '/maternal-child/children/$childId',
      repository: repository,
      session: session,
      settle: false,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await session.expire();
    await tester.pumpAndSettle();
    repository.pending!.complete(repository.record());
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsNothing);
    expect(
      find.text('Your session has expired. Sign in again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
