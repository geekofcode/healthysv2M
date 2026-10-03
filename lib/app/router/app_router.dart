import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/domain/session.dart';
import '../../features/auth/presentation/auth_page.dart';
import '../../features/auth/presentation/profile_page.dart';

import '../../features/home/presentation/home_page.dart';
import '../../features/teleconsultations/presentation/teleconsultations_page.dart';
import '../../features/teleconsultations/presentation/teleconsultation_room_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/notifications/presentation/notification_detail_page.dart';
import '../../features/notifications/presentation/notification_preferences_page.dart';
import '../../features/messaging/presentation/conversations_page.dart';
import '../../features/messaging/presentation/conversation_page.dart';
import '../../features/messaging/presentation/new_conversation_page.dart';
import '../../features/consultations/presentation/consultation_history_page.dart';
import '../../features/consultations/presentation/consultation_detail_page.dart';
import '../../features/documents/presentation/documents_page.dart';
import '../../features/documents/presentation/document_preview_page.dart';
import '../../features/appointments/presentation/appointments_page.dart';
import '../../features/appointments/presentation/appointment_detail_page.dart';
import '../../features/appointments/presentation/appointment_booking_page.dart';
import '../../features/patient/presentation/medical_record_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/laboratory/presentation/lab_results_page.dart';
import '../../features/laboratory/presentation/lab_result_detail_page.dart';
import '../../features/prescriptions/presentation/prescriptions_page.dart';
import '../../features/prescriptions/presentation/prescription_detail_page.dart';

import '../../features/maternal_child/presentation/maternal_child_page.dart';
import '../../features/maternal_child/presentation/pregnancy_detail_page.dart';
import '../../features/maternal_child/presentation/child_detail_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRouterRefresh();
  ref.listen(sessionControllerProvider, (_, _) => refresh.notify());
  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (_, state) {
      final session = ref.read(sessionControllerProvider);
      final onLogin = state.uri.path == '/login';
      if (session.status != SessionStatus.authenticated) {
        if (onLogin) return null;
        final destination = safeReturnPath(state.uri.toString());
        return Uri(
          path: '/login',
          queryParameters: {'from': destination},
        ).toString();
      }
      if (onLogin) return safeReturnPath(state.uri.queryParameters['from']);
      return null;
    },
    routes: [
      GoRoute(
        path: '/teleconsultations',
        name: 'teleconsultations',
        builder: (_, _) => const TeleconsultationsPage(),
      ),
      GoRoute(
        path: '/teleconsultations/:id',
        name: 'teleconsultation-room',
        builder: (_, state) =>
            TeleconsultationRoomPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (_, _) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/notification-preferences',
        name: 'notification-preferences',
        builder: (_, _) => const NotificationPreferencesPage(),
      ),
      GoRoute(
        path: '/notifications/:id',
        name: 'notification-detail',
        builder: (_, state) =>
            NotificationDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, _) => const AuthPage(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (_, _) => const ProfilePage(),
      ),
      GoRoute(path: '/', name: 'home', builder: (_, _) => const HomePage()),
      GoRoute(
        path: '/medical-record',
        name: 'medical-record',
        builder: (_, _) => const MedicalRecordPage(),
      ),
      GoRoute(
        path: '/appointments',
        name: 'appointments',
        builder: (_, _) => const AppointmentsPage(),
      ),
      GoRoute(
        path: '/appointments/new',
        name: 'appointment-book',
        builder: (_, _) => const AppointmentBookingPage(),
      ),
      GoRoute(
        path: '/appointments/:id/reschedule',
        name: 'appointment-reschedule',
        builder: (_, state) =>
            AppointmentBookingPage(appointmentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/appointments/:id',
        name: 'appointment-detail',
        builder: (_, state) =>
            AppointmentDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/consultations',
        name: 'consultations',
        builder: (_, _) => const ConsultationHistoryPage(),
      ),
      GoRoute(
        path: '/consultations/:id/documents',
        name: 'consultation-documents',
        builder: (_, state) =>
            DocumentsPage(consultationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/consultations/:id',
        name: 'consultation-detail',
        builder: (_, state) =>
            ConsultationDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/documents',
        name: 'documents',
        builder: (_, _) => const DocumentsPage(),
      ),
      GoRoute(
        path: '/documents/:id/view',
        name: 'document-preview',
        builder: (_, state) =>
            DocumentPreviewPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/lab-results',
        name: 'lab-results',
        builder: (_, _) => const LabResultsPage(),
      ),
      GoRoute(
        path: '/lab-results/:id',
        name: 'lab-result-detail',
        builder: (_, state) =>
            LabResultDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/prescriptions',
        name: 'prescriptions',
        builder: (_, _) => const PrescriptionsPage(),
      ),
      GoRoute(
        path: '/prescriptions/:id',
        name: 'prescription-detail',
        builder: (_, state) =>
            PrescriptionDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/maternal-child',
        name: 'maternal-child',
        builder: (_, _) => const MaternalChildPage(),
      ),
      GoRoute(
        path: '/maternal-child/pregnancies/:id',
        name: 'pregnancy-detail',
        builder: (_, state) =>
            PregnancyDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/maternal-child/children/:id',
        name: 'child-detail',
        builder: (_, state) => ChildDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/messages',
        name: 'conversations',
        builder: (_, _) => const ConversationsPage(),
      ),
      GoRoute(
        path: '/messages/new',
        name: 'conversation-new',
        builder: (_, _) => const NewConversationPage(),
      ),
      GoRoute(
        path: '/messages/:id',
        name: 'conversation',
        builder: (_, state) =>
            ConversationPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (_, _) => const SettingsPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text("HEALTH'YS")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Localizations.localeOf(context).languageCode == 'fr'
                  ? 'Page introuvable'
                  : 'Page not found',
            ),
            TextButton(
              onPressed: () => context.go('/'),
              child: Text(
                Localizations.localeOf(context).languageCode == 'fr'
                    ? 'Accueil'
                    : 'Home',
              ),
            ),
          ],
        ),
      ),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Accept only known local destinations; never redirect to external URLs.
String safeReturnPath(String? value) {
  if (value != null &&
      value.split('/').any((segment) => segment == '.' || segment == '..')) {
    return '/';
  }
  final uri = value == null ? null : Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !_knownReturnPath(uri.path)) {
    return '/';
  }
  return uri.path;
}

bool _knownReturnPath(String path) {
  if (const {
    '/',
    '/settings',
    '/profile',
    '/medical-record',
    '/appointments',
    '/appointments/new',
    '/consultations',
    '/documents',
    '/lab-results',
    '/prescriptions',
    '/maternal-child',
    '/messages',
    '/messages/new',
    '/teleconsultations',
    '/notifications',
    '/notification-preferences',
  }.contains(path)) {
    return true;
  }
  const uuid =
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';
  return RegExp('^/appointments/$uuid(?:/reschedule)?\$').hasMatch(path) ||
      RegExp('^/consultations/$uuid(?:/documents)?\$').hasMatch(path) ||
      RegExp('^/documents/$uuid/view\$').hasMatch(path) ||
      RegExp(
        '^/(?:lab-results|prescriptions|messages|notifications|teleconsultations)/$uuid\$',
      ).hasMatch(path) ||
      RegExp(
        '^/maternal-child/(?:pregnancies|children)/$uuid\$',
      ).hasMatch(path);
}

class _SessionRouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
