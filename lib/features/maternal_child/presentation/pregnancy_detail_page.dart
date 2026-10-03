import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../../patient/presentation/patient_content.dart';
import '../application/maternal_child_providers.dart';
import '../domain/maternal_child.dart';
import 'notebook_fields.dart';

class PregnancyDetailPage extends ConsumerWidget {
  const PregnancyDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fr = clinicalFrench(context);
    final provider = pregnancyDetailProvider(id);
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Grossesse' : 'Pregnancy')),
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
                    ? 'Cette grossesse est introuvable ou indisponible.'
                    : 'This pregnancy could not be found or is unavailable.',
                builder: (data) => data == null
                    ? Text(
                        fr
                            ? 'Grossesse indisponible.'
                            : 'Pregnancy unavailable.',
                      )
                    : PregnancySections(data: data),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PregnancySections extends StatelessWidget {
  const PregnancySections({super.key, required this.data});
  final PregnancyDetail data;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    final pregnancy = data.pregnancy;
    final delivery = data.delivery;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PatientSection(
          title: fr ? 'Suivi de grossesse' : 'Pregnancy follow-up',
          children: [
            PatientField(
              label: fr ? 'Numéro' : 'Number',
              value: pregnancy.pregnancyNumber,
            ),
            PatientField(
              label: fr ? 'Statut' : 'Status',
              value: notebookStatus(pregnancy.status, fr),
            ),
            PatientField(
              label: fr ? 'Terme prévu' : 'Expected delivery',
              value: notebookDate(context, pregnancy.expectedDeliveryDate),
            ),
            PatientField(
              label: fr ? 'Conception estimée' : 'Estimated conception',
              value: notebookDate(context, data.estimatedConceptionDate),
            ),
            PatientField(
              label: fr ? 'Dernières menstruations' : 'Last menstrual period',
              value: notebookDate(context, data.lastMenstrualPeriod),
            ),
          ],
        ),
        Text(
          fr ? 'Consultations prénatales' : 'Prenatal visits',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (data.prenatalVisits.isEmpty)
          Text(
            fr
                ? 'Aucune consultation prénatale enregistrée.'
                : 'No recorded prenatal visits.',
          ),
        for (final visit in data.prenatalVisits)
          PatientSection(
            title: clinicalDateTime(context, visit.visitDate),
            children: [
              PatientField(
                label: fr ? 'Âge gestationnel' : 'Gestational age',
                value: visit.gestationalAgeWeeks == null
                    ? null
                    : '${visit.gestationalAgeWeeks} ${fr ? 'semaines' : 'weeks'}',
              ),
              PatientField(
                label: fr ? 'Poids' : 'Weight',
                value: measurement(visit.weightKg, 'kg'),
              ),
              PatientField(
                label: fr ? 'Pression systolique' : 'Systolic pressure',
                value: visit.systolicPressure == null
                    ? null
                    : '${visit.systolicPressure} mmHg',
              ),
              PatientField(
                label: fr ? 'Pression diastolique' : 'Diastolic pressure',
                value: visit.diastolicPressure == null
                    ? null
                    : '${visit.diastolicPressure} mmHg',
              ),
              PatientField(
                label: fr ? 'Fréquence cardiaque fœtale' : 'Fetal heart rate',
                value: visit.fetalHeartRate == null
                    ? null
                    : '${visit.fetalHeartRate} bpm',
              ),
            ],
          ),
        Text(
          fr ? 'Naissance' : 'Birth',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (delivery == null)
          Text(fr ? 'Aucune naissance enregistrée.' : 'No recorded birth.')
        else ...[
          PatientSection(
            title: fr ? 'Accouchement' : 'Delivery',
            children: [
              PatientField(
                label: fr ? 'Date' : 'Date',
                value: clinicalDateTime(context, delivery.deliveryDate),
              ),
              PatientField(
                label: fr ? 'Type' : 'Type',
                value: notebookStatus(delivery.deliveryType, fr),
              ),
            ],
          ),
          if (delivery.newborns.isEmpty)
            Text(
              fr
                  ? 'Aucune information nouveau-né disponible.'
                  : 'No newborn information available.',
            ),
          for (final newborn in delivery.newborns)
            PatientSection(
              title: fr ? 'Nouveau-né' : 'Newborn',
              children: [
                BirthMeasurements(
                  birthOrder: newborn.birthOrder,
                  weight: newborn.birthWeightKg,
                  height: newborn.birthHeightCm,
                  head: newborn.headCircumferenceCm,
                  apgar1: newborn.apgar1,
                  apgar5: newborn.apgar5,
                  status: newborn.status,
                ),
              ],
            ),
        ],
      ],
    );
  }
}
