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
import 'package:healthysv2/features/laboratory/data/lab_result_repository.dart';
import 'package:healthysv2/features/laboratory/domain/lab_result.dart';
import 'package:healthysv2/features/prescriptions/data/prescription_repository.dart';
import 'package:healthysv2/features/prescriptions/domain/prescription.dart';
import 'features/laboratory/lab_result_fixtures.dart' as lab;
import 'features/prescriptions/prescription_fixtures.dart' as rx;

const resultId = '00000000-0000-0000-0000-000000000701';
const prescriptionId = '00000000-0000-0000-0000-000000000702';

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

class LabRepository implements LabResultRepository {
  Object? error;
  bool empty = false;
  int calls = 0;
  final pages = <int>[];
  Completer<LabResultDetail>? pending;
  @override
  Future<LabResultPage> list(
    LabResultListQuery query, {
    CancelToken? cancelToken,
  }) async {
    pages.add(query.page);
    if (error != null) throw error!;
    final json = lab.pageJson();
    (json['content'] as List).first['id'] = resultId;
    if (empty) json['content'] = [];
    json['page'] = {
      'number': query.page,
      'size': 20,
      'totalElements': empty ? 0 : 21,
      'totalPages': empty ? 0 : 2,
      'first': query.page == 0,
      'last': empty || query.page == 1,
    };
    return LabResultPage.fromJson(json);
  }

  @override
  Future<LabResultDetail> detail(String id, {CancelToken? cancelToken}) async {
    calls++;
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return record();
  }

  LabResultDetail record() {
    final json = lab.detailJson();
    json['result']['id'] = resultId;
    json['items'][0]['value'] = '< 5.20';
    json['items'][0]['interpretation'] = 'Provided laboratory interpretation';
    json['items'][0]['abnormalFlag'] = 'HIGH';
    if (empty) json['items'] = [];
    return LabResultDetail.fromJson(json);
  }
}

class RxRepository implements PrescriptionRepository {
  Object? error;
  bool empty = false;
  bool expired = true;
  final pages = <int>[];
  @override
  Future<PrescriptionPage> list(
    PrescriptionListQuery query, {
    CancelToken? cancelToken,
  }) async {
    pages.add(query.page);
    if (error != null) throw error!;
    final json = rx.pageJson();
    json['content'][0]['id'] = prescriptionId;
    json['content'][0]['expired'] = expired;
    if (empty) json['content'] = [];
    json['page'] = {
      'number': query.page,
      'size': 20,
      'totalElements': empty ? 0 : 21,
      'totalPages': empty ? 0 : 2,
      'first': query.page == 0,
      'last': empty || query.page == 1,
    };
    return PrescriptionPage.fromJson(json);
  }

  @override
  Future<PrescriptionDetail> detail(
    String id, {
    CancelToken? cancelToken,
  }) async {
    if (error != null) throw error!;
    final json = rx.detailJson();
    json['prescription']['id'] = prescriptionId;
    json['prescription']['expired'] = expired;
    if (empty) {
      json['items'] = [];
      json['dispensations'] = [];
    }
    return PrescriptionDetail.fromJson(json);
  }
}

Future<ProviderContainer> pump(
  WidgetTester tester,
  String path, {
  LabRepository? laboratory,
  RxRepository? prescriptions,
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
      labResultRepositoryProvider.overrideWithValue(
        laboratory ?? LabRepository(),
      ),
      prescriptionRepositoryProvider.overrideWithValue(
        prescriptions ?? RxRepository(),
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
    'safe return paths accept only known local UUID laboratory and prescription routes',
    () {
      for (final path in [
        '/lab-results',
        '/lab-results/$resultId',
        '/prescriptions',
        '/prescriptions/$prescriptionId',
      ]) {
        expect(safeReturnPath(path), path);
      }
      for (final path in [
        '/lab-results/private',
        '/prescriptions/../documents',
        'https://evil.example/prescriptions/$prescriptionId',
      ]) {
        expect(safeReturnPath(path), '/');
      }
    },
  );
  testWidgets(
    'laboratory history paginates and navigates to provided result values',
    (tester) async {
      final repository = LabRepository();
      await pump(tester, '/lab-results', laboratory: repository);
      expect(find.text('LR-1'), findsOneWidget);
      expect(find.textContaining('Labo'), findsWidgets);
      expect(find.text('patient-1'), findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(repository.pages.last, 1);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      await reveal(tester, '< 5.20');
      expect(find.text('mmol/L'), findsOneWidget);
      await reveal(tester, 'Provided laboratory interpretation');
      expect(find.text('High'), findsOneWidget);
      expect(find.text('exam-1'), findsNothing);
    },
  );
  testWidgets(
    'French laboratory detail distinguishes reference bounds and supplied flag',
    (tester) async {
      await pump(tester, '/lab-results/$resultId', french: true);
      expect(find.text('Validé'), findsOneWidget);
      await reveal(tester, 'Référence minimum');
      expect(find.text('3.9'), findsOneWidget);
      await reveal(tester, 'Référence maximum');
      expect(find.text('6.1'), findsOneWidget);
      await reveal(tester, 'Indicateur du laboratoire');
      expect(find.text('Élevé'), findsOneWidget);
    },
  );
  testWidgets(
    'prescriptions paginate and show distinct expiry from dispensing status',
    (tester) async {
      final repository = RxRepository();
      await pump(tester, '/prescriptions', prescriptions: repository);
      expect(find.textContaining('Partially dispensed'), findsOneWidget);
      expect(find.textContaining('Validity date has passed'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(repository.pages.last, 1);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      await reveal(tester, 'Strength');
      expect(find.text('10 mg'), findsOneWidget);
      await reveal(tester, 'Dosage');
      expect(find.text('1 comprimé'), findsOneWidget);
      await reveal(tester, 'Prescribed quantity');
      expect(find.text('30'), findsOneWidget);
      await reveal(tester, 'Remaining quantity');
      expect(find.text('20'), findsOneWidget);
      await reveal(tester, 'Dispensing history');
      await reveal(tester, 'Pharmacie');
      expect(find.text('D-1'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('pharmacy-1'), findsNothing);
    },
  );
  testWidgets(
    'French prescription has medication instructions and quantity labels',
    (tester) async {
      await pump(tester, '/prescriptions/$prescriptionId', french: true);
      expect(find.text('Partiellement dispensée'), findsOneWidget);
      await reveal(tester, 'Instructions');
      expect(find.text('Après le repas'), findsOneWidget);
      await reveal(tester, 'Quantité prescrite');
      await reveal(tester, 'Quantité dispensée');
      await reveal(tester, 'Quantité restante');
      await reveal(tester, 'Historique de dispensation');
    },
  );
  testWidgets('empty laboratory history and prescription detail are explicit', (
    tester,
  ) async {
    await pump(
      tester,
      '/lab-results',
      laboratory: LabRepository()..empty = true,
    );
    expect(find.text('No validated results available.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pump(
      tester,
      '/prescriptions/$prescriptionId',
      prescriptions: RxRepository()..empty = true,
    );
    expect(find.text('No medications available.'), findsOneWidget);
    expect(find.text('No recorded dispensations.'), findsOneWidget);
  });
  testWidgets(
    'forbidden reads hide private error and support deliberate retry',
    (tester) async {
      final repository = LabRepository()
        ..error = const AppException(
          kind: AppErrorKind.forbidden,
          statusCode: 403,
          message: 'private-laboratory-text',
        );
      await pump(tester, '/lab-results/$resultId', laboratory: repository);
      expect(find.text('private-laboratory-text'), findsNothing);
      expect(
        find.text('You do not have permission to perform this action.'),
        findsOneWidget,
      );
      expect(repository.calls, 1);
      repository.error = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(find.text('LR-1'), findsOneWidget);
    },
  );
  testWidgets('missing prescription detail uses controlled unavailable state', (
    tester,
  ) async {
    await pump(
      tester,
      '/prescriptions/$prescriptionId',
      prescriptions: RxRepository()
        ..error = const AppException(
          kind: AppErrorKind.unknown,
          statusCode: 404,
          message: 'private',
        ),
    );
    expect(
      find.text('This prescription could not be found or is unavailable.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });
  testWidgets(
    'expired session during pending laboratory read removes content and guards route',
    (tester) async {
      final repository = LabRepository()
        ..pending = Completer<LabResultDetail>();
      final session = Session();
      await pump(
        tester,
        '/lab-results/$resultId',
        laboratory: repository,
        session: session,
        settle: false,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      session.expire();
      await tester.pumpAndSettle();
      repository.pending!.complete(repository.record());
      await tester.pumpAndSettle();
      expect(find.text('LR-1'), findsNothing);
      expect(
        find.text('Your session has expired. Sign in again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
