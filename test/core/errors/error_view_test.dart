import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/core/errors/error_view.dart';

void main() {
  for (final language in ['en', 'fr']) {
    testWidgets('displays safe $language copy and retries', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: const [Locale('en'), Locale('fr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: ErrorView(
              error: const AppException(
                kind: AppErrorKind.server,
                message: 'Database password leaked',
                correlationId: 'support-123',
              ),
              onRetry: () => retries++,
            ),
          ),
        ),
      );
      expect(find.text('Database password leaked'), findsNothing);
      expect(
        find.text(
          localizedErrorMessage(AppErrorKind.server, french: language == 'fr'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('support-123'), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(retries, 1);
    });
  }
}
