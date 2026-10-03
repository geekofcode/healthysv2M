String consultationStatus(String value, {required bool french}) =>
    switch (value.toUpperCase()) {
      'COMPLETED' => french ? 'Terminée' : 'Completed',
      'IN_PROGRESS' => french ? 'En cours' : 'In progress',
      'CANCELLED' => french ? 'Annulée' : 'Cancelled',
      'DRAFT' => french ? 'Brouillon' : 'Draft',
      _ => french ? 'Statut non renseigné' : 'Status not provided',
    };
String? clinicalLabel(String? value, {required bool french}) {
  if (value == null || value.isEmpty) return null;
  return switch (value.toUpperCase()) {
    'CONSULTATION' ||
    'GENERAL' ||
    'GENERAL_MEDICINE' => french ? 'Consultation' : 'Consultation',
    'INITIAL' => french ? 'Première consultation' : 'Initial consultation',
    'FOLLOW_UP' => french ? 'Suivi' : 'Follow-up',
    'EMERGENCY' => french ? 'Urgence' : 'Emergency',
    'TELECONSULTATION' => french ? 'Téléconsultation' : 'Teleconsultation',
    'PRIMARY' => french ? 'Principal' : 'Primary',
    'SECONDARY' => french ? 'Secondaire' : 'Secondary',
    'ACTIVE' => french ? 'Actif' : 'Active',
    'RESOLVED' => french ? 'Résolu' : 'Resolved',
    'CONFIRMED' => french ? 'Confirmé' : 'Confirmed',
    'SUSPECTED' => french ? 'Suspecté' : 'Suspected',
    'SOAP' => french ? 'Note clinique' : 'Clinical note',
    'SUMMARY' => french ? 'Résumé' : 'Summary',
    'PATIENT' => french ? 'Information patient' : 'Patient information',
    _ => value,
  };
}
