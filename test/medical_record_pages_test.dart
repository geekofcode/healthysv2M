import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/app/healthys_app.dart';
import 'package:healthysv2/app/router/app_router.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/patient/application/patient_dashboard_provider.dart';
import 'package:healthysv2/features/patient/application/patient_medical_record_provider.dart';
import 'package:healthysv2/features/patient/domain/patient_dashboard.dart';
import 'package:healthysv2/features/patient/domain/patient_medical_record.dart';
import 'package:healthysv2/features/patient/presentation/medical_record_page.dart';

const sample = PatientMedicalRecord(
  patient: PatientOverview(
    id: 'pt1',
    personId: 'p1',
    bloodGroup: 'O',
    rhesus: 'POSITIVE',
  ),
  allergies: [
    PatientAllergy(
      allergen: 'Penicillin',
      reaction: 'Rash',
      allergyType: 'DRUG',
      severity: 'HIGH',
      status: 'ACTIVE',
    ),
    PatientAllergy(allergen: 'Historical pollen allergy', status: 'INACTIVE'),
  ],
  chronicDiseases: [
    PatientChronicDisease(
      diagnosisCode: 'E11',
      diagnosisLabel: 'Type 2 diabetes',
      status: 'ACTIVE',
    ),
  ],
  medicalHistories: [PatientMedicalHistory(condition: 'Childhood asthma')],
  surgicalHistories: [
    PatientSurgicalHistory(
      procedureName: 'Appendectomy',
      organizationId: 'never-show-organization-uuid',
    ),
  ],
  familyHistories: [
    PatientFamilyHistory(
      relationship: 'MOTHER',
      condition: 'Family hypertension',
    ),
  ],
  disabilities: [
    PatientDisability(
      type: 'PHYSICAL',
      description: 'Mobility support',
      status: 'ACTIVE',
    ),
  ],
  flags: [
    PatientAlertFlag(
      label: 'Fall risk',
      flagType: 'CLINICAL',
      severity: 'HIGH',
      active: true,
    ),
  ],
  emergencyProfile: PatientEmergencyProfile(
    active: true,
    bloodGroupVisible: true,
    allergiesVisible: true,
    emergencyContactVisible: true,
  ),
  emergencyContacts: [
    PatientEmergencyContact(
      firstName: 'Grace',
      lastName: 'Hopper',
      relationship: 'SPOUSE',
      phone: '555-0100',
      email: 'grace@example.com',
    ),
  ],
);

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'p1'}),
  );
  void markExpired() =>
      state = const SessionState(status: SessionStatus.expired);
}

Future<void> pumpRecord(
  WidgetTester tester,
  Future<PatientMedicalRecord?> Function() load, {
  bool french = false,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sessionControllerProvider.overrideWith(_Session.new),
        patientMedicalRecordProvider.overrideWith((ref) => load()),
      ],
      child: MaterialApp(
        locale: Locale(french ? 'fr' : 'en'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const MedicalRecordPage(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> reveal(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  expect(find.text(text), findsWidgets);
}

void main() {
  testWidgets(
    'record renders all clinical sections including inactive allergy history',
    (tester) async {
      await pumpRecord(tester, () async => sample);
      expect(find.text('Medical record'), findsOneWidget);
      for (final value in [
        'Penicillin',
        'Historical pollen allergy',
        'Inactive',
        'Type 2 diabetes',
        'E11',
        'Childhood asthma',
        'Appendectomy',
        'Family hypertension',
        'Mother',
        'Mobility support',
        'Emergency profile',
        'Enabled',
        'Grace Hopper',
        '555-0100',
        'grace@example.com',
      ]) {
        await reveal(tester, value);
      }
      expect(find.text('never-show-organization-uuid'), findsNothing);
      expect(find.byType(Switch), findsNothing);
    },
  );
  testWidgets(
    'French sections localize clinical labels and emergency sharing',
    (tester) async {
      await pumpRecord(tester, () async => sample, french: true);
      expect(find.text('Dossier médical'), findsOneWidget);
      for (final value in [
        'Maladies chroniques',
        'Antécédents médicaux',
        'Antécédents chirurgicaux',
        'Antécédents familiaux',
        'Mère',
        'Handicaps',
        'Physique',
        'Profil d’urgence',
        'Activé',
        'Autorisé',
        'Non autorisé',
        'Contacts d’urgence',
      ]) {
        await reveal(tester, value);
      }
    },
  );
  testWidgets(
    'empty record explicitly distinguishes absent recorded information',
    (tester) async {
      await pumpRecord(
        tester,
        () async => const PatientMedicalRecord(patient: PatientOverview()),
      );
      for (final value in [
        'No recorded active alerts.',
        'No recorded allergies.',
        'No recorded chronic conditions.',
        'No recorded medical history.',
        'No recorded surgical history.',
        'No recorded family history.',
        'No recorded disabilities.',
        'No emergency profile configured.',
        'No recorded emergency contacts.',
      ]) {
        await reveal(tester, value);
      }
      expect(find.text('Not provided'), findsWidgets);
    },
  );
  testWidgets(
    'loading hides clinical data and null gives missing-record guidance',
    (tester) async {
      final pending = Completer<PatientMedicalRecord?>();
      await pumpRecord(tester, () => pending.future, settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Penicillin'), findsNothing);
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No patient record is linked to your account. Contact your organization.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets('404 missing record and 403 access denial use controlled copy', (
    tester,
  ) async {
    await pumpRecord(
      tester,
      () async => throw const AppException(
        kind: AppErrorKind.unknown,
        statusCode: 404,
        message: 'private details',
      ),
    );
    expect(
      find.text(
        'No patient record is linked to your account. Contact your organization.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await pumpRecord(
      tester,
      () async => throw const AppException(
        kind: AppErrorKind.forbidden,
        statusCode: 403,
        message: 'private details',
      ),
      french: true,
    );
    expect(
      find.text('Ce dossier est réservé au patient concerné.'),
      findsOneWidget,
    );
    expect(find.text('private details'), findsNothing);
  });
  testWidgets('retry retrieves clinical data after network failure', (
    tester,
  ) async {
    var attempts = 0;
    await pumpRecord(tester, () async {
      if (++attempts == 1) {
        throw const AppException(
          kind: AppErrorKind.network,
          message: 'private details',
        );
      }
      return sample;
    });
    expect(
      find.text('Connection unavailable. Check your network.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Penicillin'), findsOneWidget);
  });
  testWidgets(
    'pull refresh failure hides previously loaded clinical information',
    (tester) async {
      var attempts = 0;
      await pumpRecord(tester, () async {
        if (++attempts > 1) {
          throw const AppException(
            kind: AppErrorKind.network,
            message: 'private details',
          );
        }
        return sample;
      });
      expect(find.text('Penicillin'), findsOneWidget);
      await tester.fling(find.byType(ListView), const Offset(0, 350), 1000);
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('Penicillin'), findsNothing);
      expect(
        find.text('Connection unavailable. Check your network.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'session expiration guards medical record and removes clinical data',
    (tester) async {
      final session = _Session();
      final container = ProviderContainer(
        overrides: [
          sessionControllerProvider.overrideWith(() => session),
          patientDashboardProvider.overrideWith((ref) async => null),
          patientMedicalRecordProvider.overrideWith((ref) async => sample),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HealthysApp(),
        ),
      );
      container.read(appRouterProvider).go('/medical-record');
      await tester.pumpAndSettle();
      expect(find.text('Penicillin'), findsOneWidget);
      session.markExpired();
      await tester.pumpAndSettle();
      expect(find.text('Penicillin'), findsNothing);
      expect(find.text('Medical record'), findsNothing);
      expect(
        find.text('Your session has expired. Sign in again.'),
        findsOneWidget,
      );
    },
  );
}
