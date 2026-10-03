import 'package:flutter/material.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../../patient/presentation/patient_content.dart';

String notebookDate(BuildContext context, String? date) {
  if (date == null) {
    return clinicalFrench(context) ? 'Non renseigné' : 'Not provided';
  }
  final parsed = DateTime.tryParse(date);
  if (parsed == null) {
    return clinicalFrench(context) ? 'Non renseigné' : 'Not provided';
  }
  return MaterialLocalizations.of(
    context,
  ).formatMediumDate(DateTime(parsed.year, parsed.month, parsed.day));
}

String? measurement(String? value, String unit) =>
    value == null ? null : '$value $unit';
String notebookStatus(String value, bool fr) => switch (value) {
  'ACTIVE' => fr ? 'En cours' : 'Active',
  'DELIVERED' => fr ? 'Accouchement enregistré' : 'Delivered',
  'COMPLETED' => fr ? 'Terminée' : 'Completed',
  'CANCELLED' => fr ? 'Annulée' : 'Cancelled',
  'PLANNED' => fr ? 'Prévue' : 'Planned',
  'ADMINISTERED' => fr ? 'Administrée' : 'Administered',
  'MISSED' => fr ? 'Non réalisée' : 'Missed',
  'REFUSED' => fr ? 'Refusée' : 'Refused',
  'HEALTHY' => fr ? 'En bonne santé' : 'Healthy',
  'VAGINAL' => fr ? 'Voie vaginale' : 'Vaginal',
  'CESAREAN' => fr ? 'Césarienne' : 'Cesarean',
  'ASSISTED' => fr ? 'Voie vaginale assistée' : 'Assisted vaginal',
  _ => value,
};

class BirthMeasurements extends StatelessWidget {
  const BirthMeasurements({
    super.key,
    this.birthOrder,
    this.weight,
    this.height,
    this.head,
    this.apgar1,
    this.apgar5,
    required this.status,
  });
  final int? birthOrder, apgar1, apgar5;
  final String? weight, height, head;
  final String status;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PatientField(
          label: fr ? 'Ordre de naissance' : 'Birth order',
          value: birthOrder?.toString(),
        ),
        PatientField(
          label: fr ? 'Poids à la naissance' : 'Birth weight',
          value: measurement(weight, 'kg'),
        ),
        PatientField(
          label: fr ? 'Taille à la naissance' : 'Birth length',
          value: measurement(height, 'cm'),
        ),
        PatientField(
          label: fr ? 'Périmètre crânien' : 'Head circumference',
          value: measurement(head, 'cm'),
        ),
        PatientField(
          label: fr ? 'Apgar à 1 minute' : 'Apgar at 1 minute',
          value: apgar1?.toString(),
        ),
        PatientField(
          label: fr ? 'Apgar à 5 minutes' : 'Apgar at 5 minutes',
          value: apgar5?.toString(),
        ),
        PatientField(
          label: fr ? 'Statut' : 'Status',
          value: notebookStatus(status, fr),
        ),
      ],
    );
  }
}
