Map<String, dynamic> pregnancyJson() => {
  'id': 'pregnancy-1',
  'pregnancyNumber': 'G-001',
  'motherPatientId': 'mother-1',
  'expectedDeliveryDate': '2027-03-10',
  'status': 'ONGOING',
  'createdAt': '2026-07-01T10:00:00Z',
};
Map<String, dynamic> childJson() => {
  'id': 'record-1',
  'childPatientId': 'child-1',
  'firstName': 'Emma',
  'lastName': null,
  'dateOfBirth': '2026-01-03',
  'sex': 'FEMALE',
  'status': 'ACTIVE',
  'createdAt': '2026-01-03T10:00:00Z',
};
Map<String, dynamic> pregnancyDetailJson() => {
  'pregnancy': pregnancyJson(),
  'estimatedConceptionDate': null,
  'lastMenstrualPeriod': '2026-06-03',
  'prenatalVisits': [
    {
      'id': 'visit-1',
      'visitDate': '2026-08-01T10:00:00-04:00',
      'gestationalAgeWeeks': 8,
      'weightKg': 62.5,
      'systolicPressure': 110,
      'diastolicPressure': 70,
      'fetalHeartRate': null,
    },
  ],
  'delivery': {
    'id': 'delivery-1',
    'deliveryDate': '2026-01-03T10:00:00Z',
    'deliveryType': 'VAGINAL',
    'newborns': [
      {
        'id': 'newborn-1',
        'childPatientId': 'child-1',
        'birthOrder': 1,
        'birthWeightKg': 3.25,
        'birthHeightCm': 50,
        'headCircumferenceCm': null,
        'apgar1': 8,
        'apgar5': 9,
        'status': 'ACTIVE',
      },
    ],
  },
};
Map<String, dynamic> childDetailJson() => {
  'child': childJson(),
  'birth': {
    'deliveryDate': '2026-01-03T10:00:00Z',
    'deliveryType': 'VAGINAL',
    'birthOrder': 1,
    'birthWeightKg': 3.25,
    'birthHeightCm': 50,
    'headCircumferenceCm': null,
    'apgar1': 8,
    'apgar5': 9,
    'status': 'ACTIVE',
  },
  'vaccinations': [
    {
      'id': 'vaccination-1',
      'vaccineCatalogId': null,
      'vaccineCode': null,
      'vaccineName': null,
      'doseNumber': 1,
      'administeredAt': '2026-03-03T10:00:00Z',
      'nextDueDate': '2026-05-03',
      'status': 'ADMINISTERED',
    },
  ],
  'growthMeasurements': [
    {
      'id': 'growth-1',
      'measuredAt': '2026-03-03T10:00:00Z',
      'weightKg': 5.2,
      'heightCm': null,
      'headCircumferenceCm': 38.5,
      'bmi': null,
    },
  ],
};
Map<String, dynamic> notebookPageJson(List<Map<String, dynamic>> content) => {
  'content': content,
  'page': {
    'number': 0,
    'size': 20,
    'totalElements': content.length,
    'totalPages': content.isEmpty ? 0 : 1,
    'first': true,
    'last': true,
  },
};
