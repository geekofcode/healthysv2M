Map<String, dynamic> consultationJson({
  String id = 'consultation-1',
  String status = 'COMPLETED',
}) => {
  'id': id,
  'consultationNumber': 'C-001',
  'patientId': 'patient-1',
  'professionalId': 'professional-1',
  'professionalName': 'Jane Smith',
  'organizationId': 'organization-1',
  'organizationName': 'Clinic',
  'type': 'CONSULTATION',
  'startedAt': '2026-10-01T14:00:00Z',
  'completedAt': '2026-10-01T14:30:00Z',
  'status': status,
};
Map<String, dynamic> consultationDetailJson() => {
  'consultation': consultationJson(),
  'diagnoses': [
    {
      'id': 'diagnosis-1',
      'diagnosisCatalogId': null,
      'catalogCode': null,
      'catalogLabel': null,
      'diagnosisType': 'PRIMARY',
      'description': 'Patient-visible diagnosis',
      'status': 'CONFIRMED',
      'diagnosedAt': '2026-10-01T14:15:00Z',
    },
  ],
  'notes': [
    {
      'id': 'note-1',
      'noteType': 'PATIENT_SUMMARY',
      'content': 'Patient-visible summary',
      'createdAt': '2026-10-01T14:00:00Z',
      'updatedAt': '2026-10-01T14:30:00Z',
    },
  ],
};
Map<String, dynamic> consultationPageJson() => {
  'content': [consultationJson()],
  'page': {
    'number': 0,
    'size': 20,
    'totalElements': 1,
    'totalPages': 1,
    'first': true,
    'last': true,
  },
};
