import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/presentation/session_issue_message.dart';
import '../../patient/application/patient_dashboard_provider.dart';
import '../../patient/presentation/patient_content.dart';
import '../../patient/presentation/patient_sections.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fr = isFrench(context);
    final session = ref.watch(sessionControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text("HEALTH'YS"),
        actions: [
          IconButton(
            onPressed: () => context.pushNamed('notifications'),
            tooltip: fr ? 'Notifications' : 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            onPressed: () => context.pushNamed('profile'),
            tooltip: fr ? 'Profil' : 'Profile',
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            onPressed: () => context.pushNamed('settings'),
            tooltip: fr ? 'Paramètres' : 'Settings',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(patientDashboardProvider);
            try {
              await ref.read(patientDashboardProvider.future);
            } catch (_) {
              /* The provider renders the controlled error state. */
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                fr ? 'Mon espace patient' : 'My patient dashboard',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              if (session.error != null) ...[
                Text(sessionIssueMessage(session.issue, french: fr)),
                TextButton(
                  onPressed: () => ref
                      .read(sessionControllerProvider.notifier)
                      .reloadProfile(),
                  child: Text(fr ? 'Réessayer' : 'Try again'),
                ),
              ],
              PatientContent(
                builder: (context, dashboard) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PatientSectionsLayout(
                      children: [
                        PatientIdentitySection(dashboard: dashboard),
                        PatientContactsSection(dashboard: dashboard),
                        PatientInsuranceSection(dashboard: dashboard),
                        PatientAlertsSection(dashboard: dashboard),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.pushNamed('appointments'),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(fr ? 'Mes rendez-vous' : 'My appointments'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.pushNamed('teleconsultations'),
                      icon: const Icon(Icons.video_call_outlined),
                      label: Text(
                        fr ? 'Mes téléconsultations' : 'My video consultations',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.pushNamed('consultations'),
                      icon: const Icon(Icons.medical_services_outlined),
                      label: Text(
                        fr ? 'Mes consultations' : 'My consultations',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.pushNamed('documents'),
                      icon: const Icon(Icons.description_outlined),
                      label: Text(fr ? 'Mes documents' : 'My documents'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.pushNamed('lab-results'),
                      icon: const Icon(Icons.science_outlined),
                      label: Text(
                        fr
                            ? 'Mes résultats de laboratoire'
                            : 'My laboratory results',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.pushNamed('prescriptions'),
                      icon: const Icon(Icons.medication_outlined),
                      label: Text(
                        fr ? 'Mes prescriptions' : 'My prescriptions',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.pushNamed('maternal-child'),
                      icon: const Icon(Icons.child_care_outlined),
                      label: Text(
                        fr ? 'Carnet mère-enfant' : 'Mother and child notebook',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.pushNamed('conversations'),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: Text(fr ? 'Ma messagerie' : 'My messages'),
                    ),
                    FilledButton.icon(
                      onPressed: () => context.pushNamed('medical-record'),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: Text(
                        fr
                            ? 'Ouvrir mon dossier médical'
                            : 'Open my medical record',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
