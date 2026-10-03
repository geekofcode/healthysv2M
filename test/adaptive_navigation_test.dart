import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:healthysv2/app/router/app_router.dart';
import 'appointment_pages_test.dart' as fixtures;
import 'package:healthysv2/features/home/presentation/home_page.dart';
import 'package:healthysv2/features/appointments/presentation/appointments_page.dart';
import 'package:healthysv2/features/appointments/presentation/appointment_detail_page.dart';
import 'package:healthysv2/app/layout/adaptive_navigation.dart';
import 'package:healthysv2/app/layout/adaptive_patient_shell.dart';

void main() {
  Future<void> showShell(
    WidgetTester tester,
    double width, {
    double scale = 1,
    bool selected = false,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: AdaptivePatientShell(
          path: selected ? '/appointments/item' : '/appointments',
          master: const AdaptiveMaster(
            path: '/appointments',
            child: Scaffold(body: Text('master')),
            selectedId: 'item',
          ),
          child: const Scaffold(body: Text('detail')),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('phone shows list then only selected detail', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showShell(tester, 390);
    expect(find.text('master'), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await showShell(tester, 390, selected: true);
    expect(find.text('master'), findsNothing);
    expect(find.text('detail'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('tablet displays readable master and detail with rail', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showShell(tester, 1100, selected: true);
    expect(find.text('master'), findsOneWidget);
    expect(find.text('detail'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('large text falls back to one pane rather than cramped split', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showShell(tester, 1100, scale: 2, selected: true);
    expect(find.text('master'), findsNothing);
    expect(find.text('detail'), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'empty tablet detail is localized and resize preserves master state',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showShell(tester, 1100);
      expect(find.text('Select an item to view its details.'), findsOneWidget);
      final masterElement = tester.element(find.text('master'));
      await showShell(tester, 390, selected: true);
      expect(find.text('master'), findsNothing);
      await showShell(tester, 1100, selected: true);
      expect(tester.element(find.text('master')), same(masterElement));
    },
  );
  testWidgets('short landscape keeps navigation scrollable without overflow', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showShell(tester, 1100, selected: true);
    tester.view.physicalSize = const Size(1100, 320);
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('selection disambiguates child and pregnancy IDs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveSelection(
          selectedId: 'same',
          listPath: '/maternal-child',
          routePath: '/maternal-child/children/same',
          split: true,
          masterVisible: true,
          child: Builder(
            builder: (context) => Text(
              '${AdaptiveNavigation.isSelected(context, 'same', routePrefix: '/maternal-child/pregnancies')}/${AdaptiveNavigation.isSelected(context, 'same', routePrefix: '/maternal-child/children')}',
            ),
          ),
        ),
      ),
    );
    expect(find.text('false/true'), findsOneWidget);
  });
  testWidgets(
    'close detail deep link returns to list without an existing stack',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/appointments/item',
        routes: [
          GoRoute(
            path: '/appointments',
            builder: (_, _) => const Scaffold(body: Text('list route')),
          ),
          GoRoute(
            path: '/appointments/item',
            builder: (_, _) => AdaptiveSelection(
              selectedId: 'item',
              listPath: '/appointments',
              routePath: '/appointments/item',
              split: false,
              masterVisible: false,
              child: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => AdaptiveNavigation.closeDetail(context),
                    child: const Text('close'),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();
      expect(find.text('list route'), findsOneWidget);
    },
  );
  testWidgets('actual router phone back restores list then home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = await fixtures.pumpAppointments(
      tester,
      fixtures.FakeAppointments(),
      '/',
    );
    final router = container.read(appRouterProvider);
    router.pushNamed('appointments');
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    router.pushNamed('appointments');
    await tester.pumpAndSettle();
    router.pushNamed(
      'appointment-detail',
      pathParameters: {'id': fixtures.appointmentId},
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentDetailPage), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentsPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'actual router tablet deep link resizes and keeps selected detail',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = await fixtures.pumpAppointments(
        tester,
        fixtures.FakeAppointments(),
        '/appointments/${fixtures.appointmentId}',
      );
      final router = container.read(appRouterProvider);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Page 2 / 2'), findsOneWidget);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.text('Page 2 / 2'), findsNothing);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/appointments/${fixtures.appointmentId}',
      );
      tester.view.physicalSize = const Size(1100, 844);
      await tester.pumpAndSettle();
      expect(find.text('Page 2 / 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to list').first);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/appointments');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'actual protected split redirects and unmounts patient panes when session expires',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = fixtures.TestSession();
      final container = await fixtures.pumpAppointments(
        tester,
        fixtures.FakeAppointments(),
        '/appointments/${fixtures.appointmentId}',
        session: session,
      );
      session.markExpired();
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/login',
      );
      expect(find.byType(AdaptivePatientShell), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
