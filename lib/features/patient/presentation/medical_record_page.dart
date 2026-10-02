import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
