import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:healthysv2/app/router/app_router.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/notifications/data/notification_repository.dart';
import 'package:healthysv2/features/notifications/application/push_controller.dart';
import 'package:healthysv2/features/notifications/presentation/notification_preferences_page.dart';
import 'package:healthysv2/features/notifications/domain/notifications.dart';
import 'package:healthysv2/features/notifications/presentation/notifications_page.dart';
import 'package:healthysv2/features/notifications/presentation/notification_detail_page.dart';

const notificationId = '00000000-0000-0000-0000-000000001810';
const resourceId = '00000000-0000-0000-0000-000000001811';

class NotificationSession extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'person-1'}),
  );
  void signOut() => state = const SessionState(status: SessionStatus.signedOut);
}

class FakePushController extends PushController {
  FakePushController(this.initial);
  final PushStatus initial;
  int enableCalls = 0;
  @override
  PushState build() => PushState(status: initial);
  @override
  Future<void> enable() async {
    enableCalls++;
    state = const PushState(status: PushStatus.enabled);
  }

  @override
  Future<void> disable() async {
    state = const PushState(status: PushStatus.idle);
  }
}

class PageRepository implements NotificationRepository {
  NotificationPreferences? savedPreferences;
  bool empty = false;
  bool read = false;
  Object? error;
  String resource = 'APPOINTMENT';
  int readAllCalls = 0;
  final queries = <NotificationQuery>[];
  HealthysNotification item() => HealthysNotification(
    id: notificationId,
    type: 'APPOINTMENT_REMINDER',
    title: 'HEALTH’YS reminder',
    body: 'Your patient dashboard has an update.',
    priority: 'NORMAL',
    createdAt: DateTime.utc(2026, 10, 3),
    status: 'DELIVERED',
    read: read,
    resourceType: resource,
    resourceId: resourceId,
    actionUrl: 'https://attacker.example',
  );
  @override
  Future<NotificationPage> list(
    NotificationQuery query, {
    CancelToken? cancelToken,
  }) async {
    queries.add(query);
    if (error != null) {
      throw error!;
    }
    return NotificationPage(
      content: empty ? [] : [item()],
      page: query.page,
      size: 20,
      totalElements: empty ? 0 : 21,
      totalPages: empty ? 0 : 2,
      last: empty || query.page == 1,
    );
  }

  @override
  Future<HealthysNotification> detail(
    String id, {
    CancelToken? cancelToken,
  }) async {
    if (error != null) {
      throw error!;
    }
    return item();
  }

  @override
  Future<HealthysNotification> markRead(
    String id, {
    CancelToken? cancelToken,
  }) async {
    read = true;
    return item();
  }

  @override
  Future<void> markAllRead({CancelToken? cancelToken}) async {
    readAllCalls++;
    read = true;
  }

  @override
  Future<int> unreadCount({CancelToken? cancelToken}) async => read ? 0 : 1;
  @override
  Future<NotificationPreferences> preferences({
    CancelToken? cancelToken,
  }) async => const NotificationPreferences(
    inAppEnabled: true,
    emailEnabled: true,
    smsEnabled: false,
    pushEnabled: false,
    locale: 'fr',
    quietHoursStart: '22:00',
    quietHoursEnd: '07:00',
  );
  @override
  Future<NotificationPreferences> savePreferences(
    NotificationPreferences preferences, {
    CancelToken? cancelToken,
  }) async {
    savedPreferences = preferences;
    return preferences;
  }

  @override
  Future<void> registerDevice(
    String installationId,
    String token,
    String platform, {
    CancelToken? cancelToken,
  }) async {}
  @override
  Future<void> unregisterDevice(
    String installationId, {
    String? accessToken,
  }) async {}
}

Future<ProviderContainer> pumpNotifications(
  WidgetTester tester,
  PageRepository repository, {
  bool detail = false,
  bool french = false,
  FakePushController? push,
  bool preferences = false,
}) async {
  final container = ProviderContainer(
    overrides: [
      sessionControllerProvider.overrideWith(NotificationSession.new),
      notificationRepositoryProvider.overrideWithValue(repository),
      pushControllerProvider.overrideWith(
        () => push ?? FakePushController(PushStatus.idle),
      ),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: preferences
        ? '/notification-preferences'
        : (detail ? '/notifications/$notificationId' : '/notifications'),
    routes: [
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (_, _) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/notifications/:id',
        name: 'notification-detail',
        builder: (_, state) =>
            NotificationDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/notification-preferences',
        name: 'notification-preferences',
        builder: (_, _) => const NotificationPreferencesPage(),
      ),
      GoRoute(
        path: '/appointments/:id',
        builder: (_, _) => const Scaffold(body: Text('Verified appointment')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: Locale(french ? 'fr' : 'en'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('notification list paginates and unread filter resets the page', (
    tester,
  ) async {
    final repository = PageRepository();
    await pumpNotifications(tester, repository);
    expect(find.text('HEALTH’YS reminder'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.page, 1);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(repository.queries.last.page, 0);
    expect(repository.queries.last.unreadOnly, isTrue);
  });
  testWidgets('French empty history and mark all read remain usable', (
    tester,
  ) async {
    final repository = PageRepository()..empty = true;
    await pumpNotifications(tester, repository, french: true);
    expect(find.text('Aucune notification.'), findsOneWidget);
    await tester.tap(find.text('Tout marquer comme lu'));
    await tester.pumpAndSettle();
    expect(repository.readAllCalls, 1);
  });
  testWidgets(
    'opening re-fetches recipient notification and ignores arbitrary action URL',
    (tester) async {
      final repository = PageRepository();
      await pumpNotifications(tester, repository, detail: true);
      expect(find.text('Unread'), findsOneWidget);
      await tester.tap(find.text('Open in my patient dashboard'));
      await tester.pumpAndSettle();
      expect(repository.read, isTrue);
      expect(find.text('Verified appointment'), findsOneWidget);
    },
  );
  testWidgets('unknown destination safely returns to notification history', (
    tester,
  ) async {
    final repository = PageRepository()..resource = 'EXTERNAL';
    await pumpNotifications(tester, repository, detail: true);
    await tester.tap(find.text('Open in my patient dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Mark all as read'), findsOneWidget);
    expect(find.text('Verified appointment'), findsNothing);
  });
  testWidgets('controlled error copy hides server medical diagnostics', (
    tester,
  ) async {
    final repository = PageRepository()
      ..error = const AppException(
        kind: AppErrorKind.forbidden,
        message: 'PRIVATE diagnosis',
      );
    await pumpNotifications(tester, repository);
    expect(find.text('PRIVATE diagnosis'), findsNothing);
    expect(
      find.text('You do not have permission to perform this action.'),
      findsOneWidget,
    );
  });
  testWidgets('logout clears displayed notifications', (tester) async {
    final container = await pumpNotifications(tester, PageRepository());
    expect(find.text('HEALTH’YS reminder'), findsOneWidget);
    (container.read(sessionControllerProvider.notifier) as NotificationSession)
        .signOut();
    await tester.pumpAndSettle();
    expect(find.text('HEALTH’YS reminder'), findsNothing);
  });
  testWidgets('push permission is requested only by explicit user action', (
    tester,
  ) async {
    final push = FakePushController(PushStatus.denied);
    await pumpNotifications(
      tester,
      PageRepository(),
      preferences: true,
      push: push,
    );
    expect(push.enableCalls, 0);
    expect(find.textContaining('Permission denied.'), findsOneWidget);
    await tester.tap(find.text('Enable / retry on this device'));
    await tester.pumpAndSettle();
    expect(push.enableCalls, 1);
    expect(
      find.text('Push notifications active on this device.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'OS authorization and failed device registration are distinguished',
    (tester) async {
      await pumpNotifications(
        tester,
        PageRepository(),
        preferences: true,
        push: FakePushController(PushStatus.registrationFailed),
      );
      expect(
        find.textContaining(
          'Permission granted, but device registration failed.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Permission denied.'), findsNothing);
    },
  );
  testWidgets(
    'changing in-app preference preserves other channels and quiet hours',
    (tester) async {
      final repository = PageRepository();
      await pumpNotifications(tester, repository, preferences: true);
      final tile = find.widgetWithText(SwitchListTile, 'In-app notifications');
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(repository.savedPreferences?.inAppEnabled, isFalse);
      expect(repository.savedPreferences?.emailEnabled, isTrue);
      expect(repository.savedPreferences?.smsEnabled, isFalse);
      expect(repository.savedPreferences?.quietHoursStart, '22:00');
      expect(repository.savedPreferences?.quietHoursEnd, '07:00');
      expect(repository.savedPreferences?.locale, 'fr');
    },
  );
  test(
    'notification routes survive authentication but reject external destinations',
    () {
      expect(
        safeReturnPath('/notifications/$notificationId'),
        '/notifications/$notificationId',
      );
      expect(
        safeReturnPath('/notification-preferences'),
        '/notification-preferences',
      );
      expect(
        safeReturnPath(
          'https://attacker.example/notifications/$notificationId',
        ),
        '/',
      );
    },
  );
}
