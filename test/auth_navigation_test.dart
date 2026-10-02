import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/app/healthys_app.dart';
import 'package:healthysv2/app/router/app_router.dart';
import 'package:healthysv2/core/config/app_config.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';

class NavigationSession extends SessionController {
  NavigationSession(this.initial);
  final SessionState initial;
  int profileRetries = 0;
  @override
  Future<void> reloadProfile() async {
    profileRetries++;
  }

  @override
  SessionState build() => initial;
  void update(SessionState next) => state = next;
  @override
  Future<void> login() async => update(
    const SessionState(
      status: SessionStatus.authenticated,
      profile: MobileProfile({
        'firstName': 'Ada',
        'lastName': 'Lovelace',
        'personNumber': 'P1',
      }),
    ),
  );
  @override
  Future<void> logout() async =>
      update(const SessionState(status: SessionStatus.signedOut));
}

void main() {
  test('return paths allow only known local pages', () {
    expect(safeReturnPath('/profile'), '/profile');
    expect(safeReturnPath('/settings?extra=1'), '/settings');
    for (final path in [
      'https://example.com',
      '//example.com',
      '/login',
      '/unknown',
      '/%2fexample.com',
    ]) {
      expect(safeReturnPath(path), '/');
    }
  });

  testWidgets(
    'guards retain router and protected destination across login and expiration',
    (tester) async {
      final session = NavigationSession(
        const SessionState(status: SessionStatus.signedOut),
      );
      final container = ProviderContainer(
        overrides: [
          sessionControllerProvider.overrideWith(() => session),
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(
              environment: 'dev',
              apiBaseUrl: 'https://api.example.com/api/v1',
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
      final router = container.read(appRouterProvider);
      router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(identical(router, container.read(appRouterProvider)), isTrue);
      session.update(const SessionState(status: SessionStatus.expired));
      await tester.pumpAndSettle();
      expect(
        find.text('Your session has expired. Sign in again.'),
        findsOneWidget,
      );
      expect(find.text('Settings'), findsNothing);
    },
  );

  testWidgets('profile shows backend identity and logout protects home', (
    tester,
  ) async {
    final session = NavigationSession(
      const SessionState(status: SessionStatus.signedOut),
    );
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(() => session),
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            environment: 'dev',
            apiBaseUrl: 'https://api.example.com/api/v1',
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
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('P1'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);
  });

  testWidgets(
    'restoration renders loading and recoverable errors render retry',
    (tester) async {
      final session = NavigationSession(const SessionState());
      final container = ProviderContainer(
        overrides: [
          sessionControllerProvider.overrideWith(() => session),
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(
              environment: 'dev',
              apiBaseUrl: 'https://api.example.com/api/v1',
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
      await tester.pump();
      expect(find.text('Restoring your session…'), findsOneWidget);
      session.update(
        const SessionState(status: SessionStatus.signedOut, error: 'network'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
    },
  );
  testWidgets('unlinked profile stays signed in with clear guidance and retry', (
    tester,
  ) async {
    final session = NavigationSession(
      const SessionState(
        status: SessionStatus.authenticated,
        error: 'missing profile',
        issue: SessionIssue.profileUnlinked,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(() => session),
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            environment: 'dev',
            apiBaseUrl: 'https://api.example.com/api/v1',
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
    container.read(appRouterProvider).go('/profile');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'You are signed in, but no HEALTH’YS profile is linked to your account yet. Contact your organization.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sign in'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(session.profileRetries, 1);
  });
}
