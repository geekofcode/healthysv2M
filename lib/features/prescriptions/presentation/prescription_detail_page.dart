import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../../patient/presentation/patient_content.dart';
import '../application/prescription_providers.dart';
import '../domain/prescription.dart';
import 'prescription_labels.dart';

class PrescriptionDetailPage extends ConsumerWidget {
  const PrescriptionDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fr = clinicalFrench(context);
    final provider = prescriptionDetailProvider(id);
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Prescription' : 'Prescription')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(provider);
            try {
              await ref.read(provider.future);
            } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              ClinicalAsyncView(
                value: ref.watch(provider),
                onRetry: () => ref.invalidate(provider),
                missingMessage: fr
                    ? 'Cette prescription est introuvable ou indisponible.'
                    : 'This prescription could not be found or is unavailable.',
                builder: (data) {
                  if (data == null) {
                    return Text(
                      fr
                          ? 'Prescription indisponible.'
                          : 'Prescription unavailable.',
                    );
                  }
                  return _PrescriptionSections(data: data);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrescriptionSections extends StatelessWidget {
  const _PrescriptionSections({required this.data});
  final PrescriptionDetail data;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    final prescription = data.prescription;
    final events = [...data.dispensations]
      ..sort((a, b) => a.dispensedAt.compareTo(b.dispensedAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PatientSection(
          title: fr ? 'Résumé' : 'Summary',
          children: [
            PatientField(
              label: fr ? 'Numéro' : 'Number',
              value: prescription.prescriptionNumber,
            ),
            PatientField(
              label: fr ? 'Prescripteur' : 'Prescriber',
              value: prescription.prescriberName,
            ),
            PatientField(
              label: fr ? 'Établissement' : 'Organization',
              value: prescription.organizationName,
            ),
            PatientField(
              label: fr ? 'Statut' : 'Status',
              value: prescriptionStatus(prescription.status, fr),
            ),
            PatientField(
              label: fr ? 'Prescrite le' : 'Prescribed',
              value: clinicalDateTime(context, prescription.prescribedAt),
            ),
            PatientField(
              label: fr ? 'Valable jusqu’au' : 'Valid until',
              value: clinicalDateTime(context, prescription.expiresAt),
            ),
            if (prescription.expired)
              Text(
                fr ? 'Date de validité dépassée' : 'Validity date has passed',
              ),
          ],
        ),
        if (data.items.isEmpty)
          Text(
            fr ? 'Aucun médicament disponible.' : 'No medications available.',
          ),
        for (final item in data.items) _Medication(item: item),
        PatientSection(
          title: fr ? 'Historique de dispensation' : 'Dispensing history',
          children: [
            if (events.isEmpty)
              Text(
                fr
                    ? 'Aucune dispensation enregistrée.'
                    : 'No recorded dispensations.',
              ),
            for (final event in events) _Dispensation(event: event),
          ],
        ),
        if (prescription.consultationId != null)
          OutlinedButton.icon(
            onPressed: () => context.pushNamed(
              'consultation-detail',
              pathParameters: {'id': prescription.consultationId!},
            ),
            icon: const Icon(Icons.medical_services_outlined),
            label: Text(fr ? 'Consultation associée' : 'Related consultation'),
          ),
      ],
    );
  }
}

class _Medication extends StatelessWidget {
  const _Medication({required this.item});
  final PrescriptionItem item;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    return PatientSection(
      title: item.medicationName,
      children: [
        PatientField(
          label: fr ? 'Nom générique' : 'Generic name',
          value: item.genericName,
        ),
        PatientField(label: fr ? 'Forme' : 'Form', value: item.form),
        PatientField(
          label: fr ? 'Concentration' : 'Strength',
          value: item.strength,
        ),
        PatientField(label: fr ? 'Posologie' : 'Dosage', value: item.dosage),
        PatientField(
          label: fr ? 'Fréquence' : 'Frequency',
          value: item.frequency,
        ),
        PatientField(
          label: fr ? 'Voie d’administration' : 'Route',
          value: item.route,
        ),
        PatientField(label: fr ? 'Durée' : 'Duration', value: item.duration),
        PatientField(
          label: fr ? 'Instructions' : 'Instructions',
          value: item.instructions,
        ),
        PatientField(
          label: fr ? 'Quantité prescrite' : 'Prescribed quantity',
          value: item.quantity,
        ),
        PatientField(
          label: fr ? 'Quantité dispensée' : 'Dispensed quantity',
          value: item.quantityDispensed,
        ),
        PatientField(
          label: fr ? 'Quantité restante' : 'Remaining quantity',
          value: item.quantityRemaining,
        ),
      ],
    );
  }
}

class _Dispensation extends StatelessWidget {
  const _Dispensation({required this.event});
  final PrescriptionDispensation event;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PatientField(
            label: fr ? 'Dispensation' : 'Dispensation',
            value: event.dispenseNumber,
          ),
          PatientField(
            label: fr ? 'Pharmacie' : 'Pharmacy',
            value: event.pharmacyName,
          ),
          PatientField(
            label: fr ? 'Date' : 'Date',
            value: clinicalDateTime(context, event.dispensedAt),
          ),
          PatientField(
            label: fr ? 'Statut' : 'Status',
            value: prescriptionStatus(event.status, fr),
          ),
          for (final item in event.items)
            PatientField(
              label: item.medicationName,
              value:
                  '${fr ? 'Quantité dispensée' : 'Dispensed quantity'} : ${item.quantityDispensed ?? (fr ? 'Non renseignée' : 'Not provided')}',
            ),
        ],
      ),
    );
  }
}
