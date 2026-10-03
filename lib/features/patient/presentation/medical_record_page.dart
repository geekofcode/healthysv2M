import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/patient_medical_record_provider.dart';
import 'medical_record_content.dart';
import 'medical_record_sections.dart';
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
            ref.invalidate(patientMedicalRecordProvider);
            try {
              await ref.read(patientMedicalRecordProvider.future);
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
                    ? 'Votre dossier médical en lecture seule'
                    : 'Your medical record, read only',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.pushNamed('consultations'),
                icon: const Icon(Icons.medical_services_outlined),
                label: Text(fr ? 'Mes consultations' : 'My consultations'),
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
                  fr ? 'Mes résultats de laboratoire' : 'My laboratory results',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.pushNamed('prescriptions'),
                icon: const Icon(Icons.medication_outlined),
                label: Text(fr ? 'Mes prescriptions' : 'My prescriptions'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.pushNamed('maternal-child'),
                icon: const Icon(Icons.child_care_outlined),
                label: Text(
                  fr ? 'Carnet mère-enfant' : 'Mother and child notebook',
                ),
              ),
              MedicalRecordContent(
                builder: (context, record) =>
                    MedicalRecordSections(record: record),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
