import 'package:flutter/material.dart';

import '../domain/patient_medical_record.dart';
import 'patient_content.dart';
import 'patient_sections.dart';

String? medicalLabel(String? value, {required bool french}) {
  if (value == null || value.isEmpty) return null;
  return switch (value.toUpperCase()) {
    'INACTIVE' => french ? 'Inactive' : 'Inactive',
    'RESOLVED' => french ? 'Résolue' : 'Resolved',
    'REMISSION' => french ? 'En rémission' : 'In remission',
    'CONFIRMED' => french ? 'Confirmée' : 'Confirmed',
    'SUSPECTED' => french ? 'Suspectée' : 'Suspected',
    'REFUTED' => french ? 'Écartée' : 'Refuted',
    'FATHER' => french ? 'Père' : 'Father',
    'MOTHER' => french ? 'Mère' : 'Mother',
    'PARENT' => french ? 'Parent' : 'Parent',
    'CHILD' => french ? 'Enfant' : 'Child',
    'SON' => french ? 'Fils' : 'Son',
    'DAUGHTER' => french ? 'Fille' : 'Daughter',
    'SIBLING' => french ? 'Frère ou sœur' : 'Sibling',
    'BROTHER' => french ? 'Frère' : 'Brother',
    'SISTER' => french ? 'Sœur' : 'Sister',
    'SPOUSE' => french ? 'Conjoint ou conjointe' : 'Spouse',
    'PARTNER' => french ? 'Partenaire' : 'Partner',
    'GRANDPARENT' => french ? 'Grand-parent' : 'Grandparent',
    'PHYSICAL' => french ? 'Physique' : 'Physical',
    'SENSORY' => french ? 'Sensorielle' : 'Sensory',
    'MENTAL' => french ? 'Psychique' : 'Mental',
    'COGNITIVE' => french ? 'Cognitive' : 'Cognitive',
    'FOOD' => french ? 'Alimentaire' : 'Food',
    'DRUG' || 'MEDICATION' => french ? 'Médicamenteuse' : 'Medication',
    'ENVIRONMENTAL' => french ? 'Environnementale' : 'Environmental',
    _ => patientLabel(value, french: french),
  };
}

class MedicalRecordSections extends StatelessWidget {
  const MedicalRecordSections({super.key, required this.record});
  final PatientMedicalRecord record;

  @override
  Widget build(BuildContext context) {
    final fr = isFrench(context);
    return PatientSectionsLayout(
      children: [
        PatientSection(
          title: fr ? 'Groupe sanguin' : 'Blood group',
          children: [
            PatientField(
              label: fr ? 'Groupe' : 'Group',
              value: record.patient.bloodGroup,
            ),
            PatientField(
              label: fr ? 'Rhésus' : 'Rhesus',
              value: patientLabel(record.patient.rhesus, french: fr),
            ),
          ],
        ),
        _alerts(context, fr),
        _allergies(context, fr),
        _chronic(context, fr),
        _medical(context, fr),
        _surgical(context, fr),
        _family(context, fr),
        _disabilities(context, fr),
        _emergency(context, fr),
        _contacts(context, fr),
      ],
    );
  }

  Widget _alerts(BuildContext context, bool fr) => PatientSection(
    title: fr ? 'Alertes principales' : 'Key alerts',
    children: [
      if (record.flags.isEmpty)
        Text(
          fr
              ? 'Aucune alerte active enregistrée.'
              : 'No recorded active alerts.',
        ),
      for (final item in record.flags)
        _entry(context, item.label, [
          PatientField(
            label: fr ? 'Type' : 'Type',
            value: medicalLabel(item.flagType, french: fr),
          ),
          PatientField(
            label: fr ? 'Gravité' : 'Severity',
            value: medicalLabel(item.severity, french: fr),
          ),
        ]),
    ],
  );

  Widget _allergies(BuildContext context, bool fr) => PatientSection(
    title: fr ? 'Allergies' : 'Allergies',
    children: [
      if (record.allergies.isEmpty)
        Text(fr ? 'Aucune allergie enregistrée.' : 'No recorded allergies.'),
      for (final item in record.allergies)
        _entry(context, item.allergen, [
          PatientField(
            label: fr ? 'Type' : 'Type',
            value: medicalLabel(item.allergyType, french: fr),
          ),
          PatientField(
            label: fr ? 'Réaction' : 'Reaction',
            value: item.reaction,
          ),
          PatientField(
            label: fr ? 'Gravité' : 'Severity',
            value: medicalLabel(item.severity, french: fr),
          ),
          PatientField(
            label: fr ? 'Statut' : 'Status',
            value: medicalLabel(item.status, french: fr),
          ),
        ]),
    ],
  );

  Widget _chronic(BuildContext context, bool fr) => PatientSection(
    title: fr ? 'Maladies chroniques' : 'Chronic conditions',
    children: [
      if (record.chronicDiseases.isEmpty)
        Text(
          fr
              ? 'Aucune maladie chronique enregistrée.'
              : 'No recorded chronic conditions.',
        ),
      for (final item in record.chronicDiseases)
        _entry(
          context,
          item.diagnosisLabel ??
              (fr ? 'Diagnostic non renseigné' : 'Diagnosis not provided'),
          [
            PatientField(
              label: fr ? 'Code du diagnostic' : 'Diagnosis code',
              value: item.diagnosisCode,
            ),
            PatientField(
              label: fr ? 'Date du diagnostic' : 'Diagnosed on',
              value: patientDate(context, item.diagnosedAt),
            ),
            PatientField(
              label: fr ? 'Statut' : 'Status',
              value: medicalLabel(item.status, french: fr),
            ),
          ],
        ),
    ],
  );

  Widget _medical(BuildContext context, bool fr) => PatientSection(
    title: fr ? 'Antécédents médicaux' : 'Medical history',
    children: [
      if (record.medicalHistories.isEmpty)
        Text(
          fr
              ? 'Aucun antécédent médical enregistré.'
              : 'No recorded medical history.',
        ),
      for (final item in record.medicalHistories)
        _entry(context, item.condition, [
          PatientField(
            label: fr ? 'Date du diagnostic' : 'Diagnosed on',
            value: patientDate(context, item.diagnosedAt),
          ),
          PatientField(
            label: fr ? 'Date de résolution' : 'Resolved on',
            value: patientDate(context, item.resolvedAt),
          ),
        ]),
    ],
  );

  Widget _surgical(BuildContext context, bool fr) => PatientSection(
    title: fr ? 'Antécédents chirurgicaux' : 'Surgical history',
    children: [
      if (record.surgicalHistories.isEmpty)
        Text(
          fr
              ? 'Aucun antécédent chirurgical enregistré.'
              : 'No recorded surgical history.',
        ),
      for (final item in record.surgicalHistories)
        _entry(context, item.procedureName, [
          PatientField(
            label: fr ? 'Date de l’intervention' : 'Procedure date',
            value: patientDate(context, item.procedureDate),
          ),
        ]),
    ],
  );

  Widget _family(BuildContext context, bool fr) => PatientSection(
    title: fr ? 'Antécédents familiaux' : 'Family history',
    children: [
      if (record.familyHistories.isEmpty)
        Text(
          fr
              ? 'Aucun antécédent familial enregistré.'
              : 'No recorded family history.',
        ),
      for (final item in record.familyHistories)
        _entry(context, item.condition, [
          PatientField(
            label: fr ? 'Lien de parenté' : 'Relationship',
            value: medicalLabel(item.relationship, french: fr),
          ),
        ]),
    ],
  );

  Widget _disabilities(BuildContext context, bool fr) => PatientSection(
    title: fr ? 'Handicaps' : 'Disabilities',
    children: [
      if (record.disabilities.isEmpty)
        Text(fr ? 'Aucun handicap enregistré.' : 'No recorded disabilities.'),
      for (final item in record.disabilities)
        _entry(
          context,
          medicalLabel(item.type, french: fr) ??
              (fr ? 'Type non renseigné' : 'Type not provided'),
          [
            PatientField(
              label: fr ? 'Description' : 'Description',
              value: item.description,
            ),
            PatientField(
              label: fr ? 'Date de début' : 'Started on',
              value: patientDate(context, item.startDate),
            ),
            PatientField(
              label: fr ? 'Statut' : 'Status',
              value: medicalLabel(item.status, french: fr),
            ),
          ],
        ),
    ],
  );

  Widget _emergency(BuildContext context, bool fr) {
    final profile = record.emergencyProfile;
    return PatientSection(
      title: fr ? 'Profil d’urgence' : 'Emergency profile',
      children: [
        if (profile == null)
          Text(
            fr
                ? 'Aucun profil d’urgence configuré.'
                : 'No emergency profile configured.',
          ),
        if (profile != null) ...[
          PatientField(
            label: fr ? 'Statut' : 'Status',
            value: profile.active
                ? (fr ? 'Activé' : 'Enabled')
                : (fr ? 'Désactivé' : 'Disabled'),
          ),
          Text(
            fr
                ? 'Informations autorisées dans le profil d’urgence'
                : 'Information allowed in the emergency profile',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _sharing(
            fr ? 'Groupe sanguin' : 'Blood group',
            profile.bloodGroupVisible,
            fr,
          ),
          _sharing(
            fr ? 'Allergies' : 'Allergies',
            profile.allergiesVisible,
            fr,
          ),
          _sharing(
            fr ? 'Maladies' : 'Conditions',
            profile.conditionsVisible,
            fr,
          ),
          _sharing(
            fr ? 'Médicaments' : 'Medications',
            profile.medicationsVisible,
            fr,
          ),
          _sharing(
            fr ? 'Contacts d’urgence' : 'Emergency contacts',
            profile.emergencyContactVisible,
            fr,
          ),
        ],
      ],
    );
  }

  Widget _sharing(String label, bool allowed, bool fr) => PatientField(
    label: label,
    value: allowed
        ? (fr ? 'Autorisé' : 'Allowed')
        : (fr ? 'Non autorisé' : 'Not allowed'),
  );

  Widget _contacts(BuildContext context, bool fr) => PatientSection(
    title: fr ? 'Contacts d’urgence' : 'Emergency contacts',
    children: [
      if (record.emergencyContacts.isEmpty)
        Text(
          fr
              ? 'Aucun contact d’urgence enregistré.'
              : 'No recorded emergency contacts.',
        ),
      for (final item in record.emergencyContacts)
        _entry(
          context,
          [
            item.firstName,
            item.lastName,
          ].whereType<String>().where((v) => v.isNotEmpty).join(' '),
          [
            PatientField(
              label: fr ? 'Lien avec le patient' : 'Relationship to patient',
              value: medicalLabel(item.relationship, french: fr),
            ),
            PatientField(label: fr ? 'Téléphone' : 'Phone', value: item.phone),
            PatientField(label: fr ? 'Courriel' : 'Email', value: item.email),
          ],
        ),
    ],
  );

  Widget _entry(BuildContext context, String title, List<Widget> fields) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.isNotEmpty
                  ? title
                  : (isFrench(context) ? 'Non renseigné' : 'Not provided'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...fields,
          ],
        ),
      );
}
