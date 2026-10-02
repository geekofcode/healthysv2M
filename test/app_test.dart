import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/app/healthys_app.dart';
import 'package:healthysv2/core/config/app_config.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/patient/application/patient_dashboard_provider.dart';

class _AuthenticatedSession extends SessionController {
  @override
  SessionState build() =>
      const SessionState(status: SessionStatus.authenticated);
}

void main() {
  testWidgets('home opens settings and returns', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientDashboardProvider.overrideWith((ref) async => null),
          sessionControllerProvider.overrideWith(_AuthenticatedSession.new),
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(environment: 'dev', apiBaseUrl: ''),
          ),
        ],
        child: const HealthysApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("HEALTH'YS"), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('dev'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('My patient dashboard'), findsOneWidget);
  });
}
