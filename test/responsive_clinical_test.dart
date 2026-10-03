import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/features/consultations/presentation/clinical_async_view.dart';
import 'package:healthysv2/features/maternal_child/presentation/notebook_fields.dart';
import 'package:healthysv2/features/patient/presentation/patient_content.dart';

Future<void> showClinical(
  WidgetTester tester,
  Widget child, {
  required double width,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 768.0, 1280.0]) {
    testWidgets('Clinical sections adapt at $width logical pixels', (
      tester,
    ) async {
      await showClinical(
        tester,
        const PatientSectionsLayout(
          children: [
            PatientSection(
              title: 'Identity',
              children: [PatientField(label: 'Name', value: 'Ada Lovelace')],
            ),
            PatientSection(
              title: 'Contact details',
              children: [
                PatientField(
                  label: 'Email',
                  value: 'a.long.patient.email.address@example.com',
                ),
              ],
            ),
          ],
        ),
        width: width,
      );
      final first = tester.getTopLeft(find.text('Identity'));
      final second = tester.getTopLeft(find.text('Contact details'));
      if (width < 720) {
        expect(second.dy, greaterThan(first.dy));
        expect(second.dx, first.dx);
      } else {
        expect(second.dy, first.dy);
        expect(second.dx, greaterThan(first.dx));
      }
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Pagination stays operable at $width with large text', (
      tester,
    ) async {
      var next = 0;
      var previous = 0;
      await showClinical(
        tester,
        ClinicalPagination(
          number: 1,
          totalPages: 3,
          last: false,
          onPrevious: () => previous++,
          onNext: () => next++,
        ),
        width: width,
        scale: 2,
      );
      await tester.tap(find.text('Previous'));
      await tester.tap(find.text('Next'));
      expect(previous, 1);
      expect(next, 1);
      expect(find.text('Page 2 / 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Birth measurements remain readable on narrow large text', (
    tester,
  ) async {
    await showClinical(
      tester,
      const BirthMeasurements(
        birthOrder: 1,
        weight: '3.2',
        height: '51',
        head: '35',
        apgar1: 8,
        apgar5: 9,
        status: 'HEALTHY',
      ),
      width: 320,
      scale: 2,
    );
    await tester.ensureVisible(find.text('Healthy'));
    await tester.pumpAndSettle();
    expect(find.text('3.2 kg'), findsOneWidget);
    expect(find.text('Head circumference'), findsOneWidget);
    expect(find.text('Healthy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Large text switches a tablet card layout to one column', (
    tester,
  ) async {
    await showClinical(
      tester,
      const PatientSectionsLayout(
        children: [
          PatientSection(title: 'Identity', children: [Text('Ada Lovelace')]),
          PatientSection(
            title: 'Emergency contacts',
            children: [Text('Family')],
          ),
        ],
      ),
      width: 768,
      scale: 2,
    );
    final identity = tester.getTopLeft(find.text('Identity'));
    final emergency = tester.getTopLeft(find.text('Emergency contacts'));
    expect(emergency.dy, greaterThan(identity.dy));
    expect(emergency.dx, identity.dx);
    expect(tester.takeException(), isNull);
  });
}
