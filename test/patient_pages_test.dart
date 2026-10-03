import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/app/healthys_app.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/patient/application/patient_dashboard_provider.dart';
import 'package:healthysv2/features/patient/application/patient_medical_record_provider.dart';
import 'package:healthysv2/features/patient/domain/patient_medical_record.dart';
import 'package:healthysv2/features/patient/domain/patient_dashboard.dart';
import 'package:healthysv2/features/home/presentation/home_page.dart';

class _PatientSession extends SessionController {
  @override
  SessionState build() =>
      const SessionState(status: SessionStatus.authenticated);
  void markExpired() =>
      state = const SessionState(status: SessionStatus.expired);
}

PatientDashboard fixture() => PatientDashboard.fromJson({
  'person': {
    'id': 'p1',
    'personNumber': 'PER-1',
    'firstName': 'Ada',
    'lastName': 'Lovelace',
    'birthDate': '1990-01-20',
    'gender': 'FEMALE',
    'contacts': [
      {
        'id': 'c1',
        'type': 'EMAIL',
        'value': 'ada@example.com',
        'primary': true,
        'verified': true,
      },
    ],
  },
  'patient': {
    'id': 'pt1',
    'personId': 'p1',
    'patientNumber': 'PAT-1',
    'bloodGroup': 'A',
    'rhesus': 'POSITIVE',
    'status': 'ACTIVE',
  },
  'addresses': [
    {
      'id': 'a1',
      'addressType': 'HOME',
      'primary': true,
      'line1': '123 Rue Test',
      'city': 'Québec',
      'province': 'QC',
      'postalCode': 'G1A 1A1',
    },
  ],
  'insurances': [
    {
      'id': 'i1',
      'insuranceCompanyId': 'company1',
      'insuranceCompanyName': 'Example insurer',
      'policyNumber': 'POL-1',
      'memberNumber': 'MEM-1',
      'primary': true,
      'startDate': '2020-01-01',
      'endDate': '2099-12-31',
    },
    {
      'id': 'i2',
      'insuranceCompanyId': 'company1',
      'insuranceCompanyName': 'Old insurer',
      'startDate': '2000-01-01',
      'endDate': '2001-01-01',
    },
    {
      'id': 'i3',
      'insuranceCompanyId': 'company1',
      'insuranceCompanyName': 'Future insurer',
      'startDate': '2099-01-01',
      'endDate': '2100-01-01',
    },
  ],
  'flags': [
    {
      'id': 'f1',
      'flagType': 'CLINICAL',
      'label': 'Important follow-up',
      'severity': 'HIGH',
      'active': true,
    },
  ],
  'allergies': [
    {
      'id': 'al1',
      'allergen': 'Penicillin',
      'reaction': 'Rash',
      'severity': 'HIGH',
      'status': 'ACTIVE',
    },
  ],
});

Future<void> pumpPage(
  WidgetTester tester,
  Future<PatientDashboard?> Function() load, {
  bool french = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        patientClockProvider.overrideWithValue(() => DateTime(2026, 10, 2)),
        sessionControllerProvider.overrideWith(_PatientSession.new),
        patientDashboardProvider.overrideWith((ref) => load()),
      ],
      child: MaterialApp(
        locale: Locale(french ? 'fr' : 'en'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const HomePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'dashboard renders actual identity contacts insurance states and alerts',
    (tester) async {
      await pumpPage(tester, () async => fixture());
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('PAT-1'), findsOneWidget);
      expect(find.text('ada@example.com'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Current'), 300);
      expect(find.text('Current'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Expired'), 300);
      expect(find.text('Expired'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Upcoming'), 300);
      expect(find.text('Upcoming'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Penicillin'), 300);
      expect(find.text('Important follow-up'), findsOneWidget);
      expect(find.text('Penicillin'), findsOneWidget);
    },
  );
  testWidgets('French dashboard has explicit linked-record empty state', (
    tester,
  ) async {
    await pumpPage(tester, () async => null, french: true);
    expect(find.text('Mon espace patient'), findsOneWidget);
    expect(
      find.text(
        'Aucun dossier patient n’est lié à votre compte. Contactez votre établissement.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ouvrir mon dossier médical'), findsNothing);
  });
  testWidgets('linked record empty collections have explicit guidance', (
    tester,
  ) async {
    await pumpPage(
      tester,
      () async => const PatientDashboard(
        person: PatientIdentity(firstName: 'Ada'),
        patient: PatientOverview(),
      ),
    );
    expect(find.text('No contact details provided.'), findsOneWidget);
    expect(find.text('No addresses provided.'), findsOneWidget);
    expect(find.text('No insurance provided.'), findsOneWidget);
    expect(find.text('No recorded alerts or allergies.'), findsOneWidget);
  });
  testWidgets(
    '403 is a patient account message and hides clinical navigation',
    (tester) async {
      await pumpPage(
        tester,
        () async => throw const AppException(
          kind: AppErrorKind.forbidden,
          statusCode: 403,
          message: 'private backend detail',
        ),
      );
      expect(
        find.text('This space is available to patient accounts only.'),
        findsOneWidget,
      );
      expect(find.text('private backend detail'), findsNothing);
      expect(find.text('Open my medical record'), findsNothing);
    },
  );
  testWidgets('404 gives linked-record guidance', (tester) async {
    await pumpPage(
      tester,
      () async => throw const AppException(
        kind: AppErrorKind.unknown,
        statusCode: 404,
        message: 'secret',
      ),
    );
    expect(
      find.text(
        'No patient record is linked to your account. Contact your organization.',
      ),
      findsOneWidget,
    );
  });
  testWidgets('network retry reloads and displays dashboard', (tester) async {
    var attempts = 0;
    await pumpPage(tester, () async {
      if (++attempts == 1) {
        throw const AppException(kind: AppErrorKind.network, message: 'secret');
      }
      return fixture();
    });
    expect(
      find.text('Connection unavailable. Check your network.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });
  testWidgets('loading does not invent patient details', (tester) async {
    final pending = Completer<PatientDashboard?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_PatientSession.new),
          patientDashboardProvider.overrideWith((ref) => pending.future),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);
    pending.complete(null);
    await tester.pumpAndSettle();
  });
  testWidgets(
    'medical record is reachable and session expiry protects its contents',
    (tester) async {
      final session = _PatientSession();
      final container = ProviderContainer(
        overrides: [
          sessionControllerProvider.overrideWith(() => session),
          patientDashboardProvider.overrideWith((ref) async => fixture()),
          patientMedicalRecordProvider.overrideWith(
            (ref) async => PatientMedicalRecord(
              patient: fixture().patient,
              allergies: fixture().allergies,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HealthysApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Open my medical record'), 400);
      await tester.ensureVisible(find.text('Open my medical record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open my medical record'));
      await tester.pumpAndSettle();
      expect(find.text('Medical record'), findsOneWidget);
      expect(find.text('Penicillin'), findsOneWidget);
      session.markExpired();
      await tester.pumpAndSettle();
      expect(find.text('Medical record'), findsNothing);
      expect(find.text('Penicillin'), findsNothing);
      expect(
        find.text('Your session has expired. Sign in again.'),
        findsOneWidget,
      );
    },
  );
}
