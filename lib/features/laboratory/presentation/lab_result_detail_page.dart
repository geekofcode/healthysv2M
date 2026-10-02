import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../../patient/presentation/patient_content.dart';
import '../application/lab_result_providers.dart';
import '../domain/lab_result.dart';

class LabResultDetailPage extends ConsumerWidget {
  const LabResultDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fr = clinicalFrench(context);
    final provider = labResultDetailProvider(id);
    return Scaffold(
      appBar: AppBar(
        title: Text(fr ? 'Résultat de laboratoire' : 'Laboratory result'),
      ),
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
                    ? 'Ce résultat est introuvable ou indisponible.'
                    : 'This result could not be found or is unavailable.',
                builder: (data) {
                  if (data == null) {
                    return Text(
                      fr ? 'Résultat indisponible.' : 'Result unavailable.',
                    );
                  }
                  return _ResultSections(data: data);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultSections extends StatelessWidget {
  const _ResultSections({required this.data});
  final LabResultDetail data;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    final result = data.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PatientSection(
          title: fr ? 'Résumé' : 'Summary',
          children: [
            PatientField(
              label: fr ? 'Numéro de résultat' : 'Result number',
              value: result.resultNumber,
            ),
            PatientField(
              label: fr ? 'Demande' : 'Order',
              value: result.orderNumber,
            ),
            PatientField(
              label: fr ? 'Laboratoire' : 'Laboratory',
              value: result.laboratoryName,
            ),
            PatientField(
              label: fr ? 'Statut' : 'Status',
              value: fr ? 'Validé' : 'Validated',
            ),
            PatientField(
              label: fr ? 'Demandé le' : 'Ordered',
              value: clinicalDateTime(context, result.orderedAt),
            ),
            PatientField(
              label: fr ? 'Réalisé le' : 'Performed',
              value: clinicalDateTime(context, result.performedAt),
            ),
            PatientField(
              label: fr ? 'Validé le' : 'Validated',
              value: clinicalDateTime(context, result.validatedAt),
            ),
          ],
        ),
        if (data.items.isEmpty)
          Text(fr ? 'Aucune mesure disponible.' : 'No measurements available.'),
        for (final item in data.items) _ResultItem(item: item),
      ],
    );
  }
}

class _ResultItem extends StatelessWidget {
  const _ResultItem({required this.item});
  final LabResultItem item;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    return PatientSection(
      title: item.parameter,
      children: [
        PatientField(label: fr ? 'Examen' : 'Test', value: item.examName),
        PatientField(
          label: fr ? 'Code examen' : 'Test code',
          value: item.examCode,
        ),
        PatientField(label: fr ? 'Valeur' : 'Value', value: item.value),
        PatientField(label: fr ? 'Unité' : 'Unit', value: item.unit),
        PatientField(
          label: fr ? 'Référence minimum' : 'Reference minimum',
          value: item.referenceMin?.toString(),
        ),
        PatientField(
          label: fr ? 'Référence maximum' : 'Reference maximum',
          value: item.referenceMax?.toString(),
        ),
        PatientField(
          label: fr
              ? 'Interprétation du laboratoire'
              : 'Laboratory interpretation',
          value: item.interpretation,
        ),
        if (item.abnormalFlag != null)
          PatientField(
            label: fr ? 'Indicateur du laboratoire' : 'Laboratory flag',
            value: labFlag(item.abnormalFlag, fr),
          ),
      ],
    );
  }
}

String? labFlag(String? flag, bool fr) => switch (flag?.toUpperCase()) {
  'NORMAL' || 'N' => fr ? 'Normal' : 'Normal',
  'HIGH' || 'H' => fr ? 'Élevé' : 'High',
  'LOW' || 'L' => fr ? 'Bas' : 'Low',
  'ABNORMAL' || 'A' => fr ? 'Anormal' : 'Abnormal',
  'CRITICAL' || 'HH' || 'LL' => fr ? 'Critique' : 'Critical',
  _ => flag,
};
