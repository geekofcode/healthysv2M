Map<String, dynamic> documentJson({
  String id = 'document-1',
  String mimeType = 'application/pdf',
  int sizeBytes = 8,
  String status = 'ACTIVE',
}) => {
  'id': id,
  'documentNumber': 'D-001',
  'patientId': 'patient-1',
  'categoryId': null,
  'categoryCode': null,
  'categoryName': null,
  'fileName': 'report.pdf',
  'mimeType': mimeType,
  'sizeBytes': sizeBytes,
  'uploadedAt': '2026-10-01T14:30:00Z',
  'status': status,
};
Map<String, dynamic> documentPageJson() => {
  'content': [documentJson()],
  'page': {
    'number': 0,
    'size': 20,
    'totalElements': 1,
    'totalPages': 1,
    'first': true,
    'last': true,
  },
};
