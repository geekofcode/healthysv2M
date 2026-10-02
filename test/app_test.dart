import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/app/healthys_app.dart';
import 'package:healthysv2/core/config/app_config.dart';

void main() {
  testWidgets('home opens settings and returns', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
    expect(find.byIcon(Icons.health_and_safety_outlined), findsOneWidget);
  });
}
