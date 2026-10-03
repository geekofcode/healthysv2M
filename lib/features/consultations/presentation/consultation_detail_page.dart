import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../patient/presentation/patient_content.dart';
import '../application/consultation_providers.dart';
import '../domain/consultation.dart';
import 'clinical_async_view.dart';
import 'consultation_labels.dart';

class ConsultationDetailPage extends ConsumerWidget {
  const ConsultationDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fr = clinicalFrench(context);
    final provider = consultationDetailProvider(id);
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Consultation' : 'Consultation')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(provider);
            try {
              await ref.read(provider.future);
            } catch (_) {
              /* The controlled state renders below. */
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              ClinicalAsyncView(
                value: ref.watch(provider),
                onRetry: () => ref.invalidate(provider),
                missingMessage: fr
                    ? 'Cette consultation est introuvable.'
                    : 'This consultation could not be found.',
                builder: (record) {
                  if (record == null) {
                    return Text(
                      fr
                          ? 'Consultation indisponible.'
                          : 'Consultation unavailable.',
                    );
                  }
                  return _ConsultationSections(record: record);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsultationSections extends StatelessWidget {
  const _ConsultationSections({required this.record});
  final ConsultationDetail record;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    final consultation = record.consultation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PatientSection(
          title: fr ? 'Résumé de la consultation' : 'Consultation summary',
          children: [
            PatientField(
              label: fr ? 'Numéro' : 'Number',
              value: consultation.consultationNumber,
            ),
            PatientField(
              label: fr ? 'Professionnel' : 'Professional',
              value: consultation.professionalName,
            ),
            PatientField(
              label: fr ? 'Établissement' : 'Organization',
              value: consultation.organizationName,
            ),
            PatientField(
              label: fr ? 'Type' : 'Type',
              value: clinicalLabel(consultation.type, french: fr),
            ),
            PatientField(
              label: fr ? 'Statut' : 'Status',
              value: consultationStatus(consultation.status, french: fr),
            ),
            PatientField(
              label: fr ? 'Début' : 'Started',
              value: clinicalDateTime(context, consultation.startedAt),
            ),
            PatientField(
              label: fr ? 'Fin' : 'Completed',
              value: clinicalDateTime(context, consultation.completedAt),
            ),
          ],
        ),
        PatientSection(
          title: fr ? 'Diagnostics' : 'Diagnoses',
          children: [
            if (record.diagnoses.isEmpty)
              Text(fr ? 'Aucun diagnostic partagé.' : 'No shared diagnoses.'),
            for (final diagnosis in record.diagnoses)
              _DiagnosisEntry(diagnosis: diagnosis),
          ],
        ),
        PatientSection(
          title: fr ? 'Notes partagées' : 'Shared notes',
          children: [
            if (record.notes.isEmpty)
              Text(fr ? 'Aucune note partagée.' : 'No shared notes.'),
            for (final note in record.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      clinicalLabel(note.noteType, french: fr) ??
                          (fr ? 'Note' : 'Note'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SelectableText(note.content),
                    const SizedBox(height: 8),
                    PatientField(
                      label: fr ? 'Créée le' : 'Created',
                      value: clinicalDateTime(context, note.createdAt),
                    ),
                    PatientField(
                      label: fr ? 'Mise à jour le' : 'Updated',
                      value: clinicalDateTime(context, note.updatedAt),
                    ),
                  ],
                ),
              ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: () => context.pushNamed(
            'consultation-documents',
            pathParameters: {'id': consultation.id},
          ),
          icon: const Icon(Icons.description_outlined),
          label: Text(
            fr
                ? 'Documents de cette consultation'
                : 'Documents for this consultation',
          ),
        ),
      ],
    );
  }
}

class _DiagnosisEntry extends StatelessWidget {
  const _DiagnosisEntry({required this.diagnosis});
  final PatientDiagnosis diagnosis;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PatientField(
            label: fr ? 'Diagnostic' : 'Diagnosis',
            value: diagnosis.catalogLabel,
          ),
          PatientField(
            label: fr ? 'Code' : 'Code',
            value: diagnosis.catalogCode,
          ),
          PatientField(
            label: fr ? 'Description' : 'Description',
            value: diagnosis.description,
          ),
          PatientField(
            label: fr ? 'Type' : 'Type',
            value: clinicalLabel(diagnosis.diagnosisType, french: fr),
          ),
          PatientField(
            label: fr ? 'Statut' : 'Status',
            value: clinicalLabel(diagnosis.status, french: fr),
          ),
          PatientField(
            label: fr ? 'Date du diagnostic' : 'Diagnosed',
            value: clinicalDateTime(context, diagnosis.diagnosedAt),
          ),
        ],
      ),
    );
  }
}
