import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/patient_dashboard_provider.dart';
import 'patient_content.dart';
import 'patient_sections.dart';

class MedicalRecordPage extends ConsumerWidget {
  const MedicalRecordPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fr = isFrench(context);
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Dossier médical' : 'Medical record')),
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
                fr
                    ? 'Résumé des informations disponibles'
                    : 'Summary of available information',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              PatientContent(
                builder: (context, dashboard) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PatientSection(
                      title: fr ? 'Groupe sanguin' : 'Blood group',
                      children: [
                        PatientField(
                          label: fr ? 'Groupe' : 'Group',
                          value: dashboard.patient.bloodGroup,
                        ),
                        PatientField(
                          label: fr ? 'Rhésus' : 'Rhesus',
                          value: patientLabel(
                            dashboard.patient.rhesus,
                            french: fr,
                          ),
                        ),
                      ],
                    ),
                    PatientAlertsSection(dashboard: dashboard),
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
