import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../../patient/presentation/patient_content.dart';
import '../application/maternal_child_providers.dart';
import '../domain/maternal_child.dart';
import 'notebook_fields.dart';

class ChildDetailPage extends ConsumerWidget {
  const ChildDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fr = clinicalFrench(context);
    final provider = childDetailProvider(id);
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Carnet enfant' : 'Child notebook')),
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
                    ? 'Ce carnet enfant est introuvable ou indisponible.'
                    : 'This child notebook could not be found or is unavailable.',
                builder: (data) => data == null
                    ? Text(
                        fr
                            ? 'Carnet enfant indisponible.'
                            : 'Child notebook unavailable.',
                      )
                    : ChildSections(data: data),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChildSections extends StatelessWidget {
  const ChildSections({super.key, required this.data});
  final ChildDetail data;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    final child = data.child;
    final birth = data.birth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PatientSection(
          title: fr ? 'Identité de l’enfant' : 'Child identity',
          children: [
            PatientField(
              label: fr ? 'Prénom' : 'First name',
              value: child.firstName,
            ),
            PatientField(
              label: fr ? 'Nom' : 'Last name',
              value: child.lastName,
            ),
            PatientField(
              label: fr ? 'Date de naissance' : 'Date of birth',
              value: notebookDate(context, child.dateOfBirth),
            ),
            PatientField(
              label: fr ? 'Sexe' : 'Sex',
              value: switch (child.sex) {
                'MALE' => fr ? 'Masculin' : 'Male',
                'FEMALE' => fr ? 'Féminin' : 'Female',
                'OTHER' => fr ? 'Autre' : 'Other',
                _ => child.sex,
              },
            ),
            PatientField(
              label: fr ? 'Statut' : 'Status',
              value: notebookStatus(child.status, fr),
            ),
          ],
        ),
        Text(
          fr ? 'Naissance' : 'Birth',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (birth == null)
          Text(fr ? 'Aucune naissance enregistrée.' : 'No recorded birth.')
        else
          PatientSection(
            title: fr ? 'Informations de naissance' : 'Birth information',
            children: [
              PatientField(
                label: fr ? 'Date' : 'Date',
                value: clinicalDateTime(context, birth.deliveryDate),
              ),
              PatientField(
                label: fr ? 'Type' : 'Type',
                value: notebookStatus(birth.deliveryType, fr),
              ),
              BirthMeasurements(
                birthOrder: birth.birthOrder,
                weight: birth.birthWeightKg,
                height: birth.birthHeightCm,
                head: birth.headCircumferenceCm,
                apgar1: birth.apgar1,
                apgar5: birth.apgar5,
                status: birth.status,
              ),
            ],
          ),
        Text(
          fr ? 'Vaccinations' : 'Vaccinations',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (data.vaccinations.isEmpty)
          Text(
            fr
                ? 'Aucune vaccination enregistrée.'
                : 'No recorded vaccinations.',
          ),
        for (final vaccination in data.vaccinations)
          PatientSection(
            title:
                vaccination.vaccineName ??
                (fr ? 'Vaccin non renseigné' : 'Vaccine not provided'),
            children: [
              PatientField(
                label: fr ? 'Code vaccin' : 'Vaccine code',
                value: vaccination.vaccineCode,
              ),
              PatientField(
                label: fr ? 'Dose' : 'Dose',
                value: vaccination.doseNumber?.toString(),
              ),
              PatientField(
                label: fr ? 'Statut' : 'Status',
                value: notebookStatus(vaccination.status, fr),
              ),
              PatientField(
                label: fr ? 'Administrée le' : 'Administered',
                value: vaccination.administeredAt == null
                    ? null
                    : clinicalDateTime(context, vaccination.administeredAt),
              ),
              PatientField(
                label: fr ? 'Prochaine échéance' : 'Next due date',
                value: notebookDate(context, vaccination.nextDueDate),
              ),
            ],
          ),
        Text(
          fr ? 'Croissance' : 'Growth',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (data.growthMeasurements.isEmpty)
          Text(
            fr
                ? 'Aucune mesure de croissance enregistrée.'
                : 'No recorded growth measurements.',
          ),
        for (final measure in data.growthMeasurements)
          PatientSection(
            title: clinicalDateTime(context, measure.measuredAt),
            children: [
              PatientField(
                label: fr ? 'Poids' : 'Weight',
                value: measurement(measure.weightKg, 'kg'),
              ),
              PatientField(
                label: fr ? 'Taille' : 'Length / height',
                value: measurement(measure.heightCm, 'cm'),
              ),
              PatientField(
                label: fr ? 'Périmètre crânien' : 'Head circumference',
                value: measurement(measure.headCircumferenceCm, 'cm'),
              ),
              if (measure.bmi != null)
                PatientField(
                  label: fr ? 'IMC enregistré' : 'Recorded BMI',
                  value: measurement(measure.bmi, 'kg/m²'),
                ),
            ],
          ),
      ],
    );
  }
}
