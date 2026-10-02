import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/session_controller.dart';
import '../../patient/application/patient_dashboard_provider.dart';
import '../../patient/presentation/patient_content.dart';
import '../../patient/presentation/patient_sections.dart';
import 'session_issue_message.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fr = isFrench(context);
    final session = ref.watch(sessionControllerProvider);
    final profile = session.profile;
    final dashboard = ref.watch(patientDashboardProvider);
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Mon profil' : 'My profile')),
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
              if (session.error != null) ...[
                Text(sessionIssueMessage(session.issue, french: fr)),
                TextButton(
                  onPressed: () => ref
                      .read(sessionControllerProvider.notifier)
                      .reloadProfile(),
                  child: Text(fr ? 'Réessayer' : 'Try again'),
                ),
              ],
              if (!dashboard.hasValue || dashboard.value == null) ...[
                if (profile != null)
                  PatientSection(
                    title: fr ? 'Profil du compte' : 'Account profile',
                    children: [
                      PatientField(
                        label: fr ? 'Nom complet' : 'Full name',
                        value: profile.displayName,
                      ),
                      if (profile.data['personNumber'] case final String number)
                        PatientField(
                          label: fr ? 'Numéro de personne' : 'Person number',
                          value: number,
                        ),
                    ],
                  ),
              ],
              PatientContent(
                builder: (context, value) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PatientIdentitySection(dashboard: value),
                    PatientContactsSection(dashboard: value),
                    PatientInsuranceSection(dashboard: value),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(sessionControllerProvider.notifier).logout(),
                icon: const Icon(Icons.logout),
                label: Text(fr ? 'Se déconnecter' : 'Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
