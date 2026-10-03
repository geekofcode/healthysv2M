import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/patient_dashboard_provider.dart';

import '../domain/patient_dashboard.dart';
import 'patient_content.dart';

String patientDate(BuildContext context, DateTime? value) => value == null
    ? ''
    : MaterialLocalizations.of(context).formatMediumDate(value);
bool isFrench(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'fr';

String? patientLabel(String? value, {required bool french}) {
  if (value == null || value.isEmpty) return null;
  return switch (value.toUpperCase()) {
    'FEMALE' => french ? 'Femme' : 'Female',
    'MALE' => french ? 'Homme' : 'Male',
    'OTHER' => french ? 'Autre' : 'Other',
    'UNKNOWN' => french ? 'Non renseigné' : 'Not provided',
    'EMAIL' => french ? 'Courriel' : 'Email',
    'PHONE' || 'MOBILE' => french ? 'Téléphone' : 'Phone',
    'HOME' => french ? 'Domicile' : 'Home',
    'WORK' => french ? 'Travail' : 'Work',
    'ACTIVE' => french ? 'Active' : 'Active',
    'HIGH' || 'SEVERE' => french ? 'Gravité élevée' : 'High severity',
    'MODERATE' || 'MEDIUM' => french ? 'Gravité modérée' : 'Moderate severity',
    'LOW' || 'MILD' => french ? 'Gravité faible' : 'Low severity',
    'CLINICAL' => french ? 'Clinique' : 'Clinical',
    'POSITIVE' => french ? 'Positif' : 'Positive',
    'NEGATIVE' => french ? 'Négatif' : 'Negative',
    _ => value,
  };
}

class PatientIdentitySection extends StatelessWidget {
  const PatientIdentitySection({super.key, required this.dashboard});
  final PatientDashboard dashboard;
  @override
  Widget build(BuildContext context) {
    final fr = isFrench(context);
    final person = dashboard.person;
    return PatientSection(
      title: fr ? 'Identité' : 'Identity',
      children: [
        PatientField(
          label: fr ? 'Nom complet' : 'Full name',
          value: person.displayName,
        ),
        PatientField(
          label: fr ? 'Numéro de patient' : 'Patient number',
          value: dashboard.patient.patientNumber,
        ),
        PatientField(
          label: fr ? 'Numéro de personne' : 'Person number',
          value: person.personNumber,
        ),
        PatientField(
          label: fr ? 'Date de naissance' : 'Date of birth',
          value: patientDate(context, person.birthDate),
        ),
        PatientField(
          label: fr ? 'Genre' : 'Gender',
          value: patientLabel(person.gender, french: fr),
        ),
      ],
    );
  }
}

class PatientContactsSection extends StatelessWidget {
  const PatientContactsSection({super.key, required this.dashboard});
  final PatientDashboard dashboard;
  @override
  Widget build(BuildContext context) {
    final fr = isFrench(context);
    return PatientSection(
      title: fr ? 'Coordonnées' : 'Contact details',
      children: [
        if (dashboard.person.contacts.isEmpty)
          Text(
            fr
                ? 'Aucune coordonnée renseignée.'
                : 'No contact details provided.',
          ),
        for (final contact in dashboard.person.contacts)
          PatientField(
            label:
                '${patientLabel(contact.type, french: fr) ?? ''}${contact.primary ? (fr ? ' • Principal' : ' • Primary') : ''}',
            value: contact.value,
          ),
        const SizedBox(height: 8),
        Text(
          fr ? 'Adresses' : 'Addresses',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (dashboard.addresses.isEmpty)
          Text(fr ? 'Aucune adresse renseignée.' : 'No addresses provided.'),
        for (final address in dashboard.addresses)
          PatientField(
            label:
                '${patientLabel(address.addressType, french: fr) ?? ''}${address.primary ? (fr ? ' • Principale' : ' • Primary') : ''}',
            value: address.formatted,
          ),
      ],
    );
  }
}

class PatientInsuranceSection extends ConsumerWidget {
  const PatientInsuranceSection({super.key, required this.dashboard});
  final PatientDashboard dashboard;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fr = isFrench(context);
    final today = ref.watch(patientClockProvider)();
    return PatientSection(
      title: fr ? 'Assurance' : 'Insurance',
      children: [
        if (dashboard.insurances.isEmpty)
          Text(fr ? 'Aucune assurance renseignée.' : 'No insurance provided.'),
        for (final insurance in dashboard.insurances) ...[
          Text(
            insurance.insuranceCompanyName ??
                (fr ? 'Assureur non renseigné' : 'Insurer not provided'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(switch (insurance.coverageOn(today)) {
            InsuranceCoverage.active => fr ? 'En cours' : 'Current',
            InsuranceCoverage.unknown =>
              fr
                  ? 'Dates de validité non renseignées'
                  : 'Validity dates not provided',
            InsuranceCoverage.expired => fr ? 'Expirée' : 'Expired',
            InsuranceCoverage.upcoming => fr ? 'À venir' : 'Upcoming',
          }),
          if (insurance.primary)
            Text(fr ? 'Assurance principale' : 'Primary insurance'),
          PatientField(
            label: fr ? 'Numéro de police' : 'Policy number',
            value: insurance.policyNumber,
          ),
          PatientField(
            label: fr ? 'Numéro de membre' : 'Member number',
            value: insurance.memberNumber,
          ),
          PatientField(
            label: fr ? 'Début de couverture' : 'Coverage starts',
            value: patientDate(context, insurance.startDate),
          ),
          PatientField(
            label: fr ? 'Fin de couverture' : 'Coverage ends',
            value: patientDate(context, insurance.endDate),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class PatientAlertsSection extends StatelessWidget {
  const PatientAlertsSection({super.key, required this.dashboard});
  final PatientDashboard dashboard;
  @override
  Widget build(BuildContext context) {
    final fr = isFrench(context);
    final flags = dashboard.flags.where((flag) => flag.active).toList();
    return PatientSection(
      title: fr ? 'Alertes principales' : 'Key alerts',
      children: [
        if (flags.isEmpty && dashboard.allergies.isEmpty)
          Text(
            fr
                ? 'Aucune alerte ou allergie enregistrée.'
                : 'No recorded alerts or allergies.',
          ),
        for (final flag in flags)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined),
            title: Text(flag.label),
            subtitle: Text(
              [
                patientLabel(flag.flagType, french: fr),
                patientLabel(flag.severity, french: fr),
              ].whereType<String>().where((v) => v.isNotEmpty).join(' • '),
            ),
          ),
        for (final allergy in dashboard.allergies)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.warning_amber_outlined),
            title: Text(allergy.allergen),
            subtitle: Text(
              [
                allergy.reaction,
                patientLabel(allergy.severity, french: fr),
                patientLabel(allergy.status, french: fr),
              ].whereType<String>().where((v) => v.isNotEmpty).join(' • '),
            ),
          ),
      ],
    );
  }
}
