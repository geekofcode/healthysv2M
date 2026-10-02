/// A history query never includes a caller-selected patient identifier.
class ConsultationListQuery {
  const ConsultationListQuery({this.page = 0, this.size = 20});
  final int page;
  final int size;
  @override
  bool operator ==(Object other) =>
      other is ConsultationListQuery &&
      other.page == page &&
      other.size == size;
  @override
  int get hashCode => Object.hash(page, size);
}

class ConsultationSummary {
  const ConsultationSummary({
    required this.id,
    required this.consultationNumber,
    required this.patientId,
    required this.professionalId,
    this.professionalName,
    required this.organizationId,
    this.organizationName,
    required this.type,
    required this.startedAt,
    this.completedAt,
    required this.status,
  });
  final String id;
  final String consultationNumber;
  final String patientId;
  final String professionalId;
  final String? professionalName;
  final String organizationId;
  final String? organizationName;
  final String type;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String status;
  factory ConsultationSummary.fromJson(Map<String, dynamic> json) {
    final status = _string(json, 'status');
    if (status != 'COMPLETED') {
      throw const FormatException(
        'Only completed consultations are patient-visible',
      );
    }
    return ConsultationSummary(
      id: _string(json, 'id'),
      consultationNumber: _string(json, 'consultationNumber'),
      patientId: _string(json, 'patientId'),
      professionalId: _string(json, 'professionalId'),
      professionalName: json['professionalName'] as String?,
      organizationId: _string(json, 'organizationId'),
      organizationName: json['organizationName'] as String?,
      type: _string(json, 'type'),
      startedAt: _instant(json, 'startedAt'),
      completedAt: json['completedAt'] == null
          ? null
          : _instant(json, 'completedAt'),
      status: status,
    );
  }
}

class ConsultationPage {
  const ConsultationPage({
    required this.content,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });
  final List<ConsultationSummary> content;
  final int number;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;
  factory ConsultationPage.fromJson(Map<String, dynamic> json) {
    final page = _map(json['page']);
    return ConsultationPage(
      content: List.unmodifiable(
        _list(
          json['content'],
        ).map((entry) => ConsultationSummary.fromJson(_map(entry))),
      ),
      number: _integer(page, 'number'),
      size: _integer(page, 'size'),
      totalElements: _integer(page, 'totalElements'),
      totalPages: _integer(page, 'totalPages'),
      first: page['first'] as bool,
      last: page['last'] as bool,
    );
  }
}

/// The server includes only explicitly patient-visible diagnoses.
class PatientDiagnosis {
  const PatientDiagnosis({
    required this.id,
    this.diagnosisCatalogId,
    this.catalogCode,
    this.catalogLabel,
    required this.diagnosisType,
    this.description,
    this.status,
    required this.diagnosedAt,
  });
  final String id;
  final String? diagnosisCatalogId;
  final String? catalogCode;
  final String? catalogLabel;
  final String diagnosisType;
  final String? description;
  final String? status;
  final DateTime diagnosedAt;
  factory PatientDiagnosis.fromJson(Map<String, dynamic> json) =>
      PatientDiagnosis(
        id: _string(json, 'id'),
        diagnosisCatalogId: json['diagnosisCatalogId'] as String?,
        catalogCode: json['catalogCode'] as String?,
        catalogLabel: json['catalogLabel'] as String?,
        diagnosisType: _string(json, 'diagnosisType'),
        description: json['description'] as String?,
        status: json['status'] as String?,
        diagnosedAt: _instant(json, 'diagnosedAt'),
      );
}

/// Deliberately excludes author identifiers and professional-only note data.
class PatientConsultationNote {
  const PatientConsultationNote({
    required this.id,
    required this.noteType,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String noteType;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  factory PatientConsultationNote.fromJson(Map<String, dynamic> json) =>
      PatientConsultationNote(
        id: _string(json, 'id'),
        noteType: _string(json, 'noteType'),
        content: _string(json, 'content'),
        createdAt: _instant(json, 'createdAt'),
        updatedAt: _instant(json, 'updatedAt'),
      );
}

class ConsultationDetail {
  const ConsultationDetail({
    required this.consultation,
    required this.diagnoses,
    required this.notes,
  });
  final ConsultationSummary consultation;
  final List<PatientDiagnosis> diagnoses;
  final List<PatientConsultationNote> notes;
  factory ConsultationDetail.fromJson(Map<String, dynamic> json) =>
      ConsultationDetail(
        consultation: ConsultationSummary.fromJson(_map(json['consultation'])),
        diagnoses: List.unmodifiable(
          _list(
            json['diagnoses'],
          ).map((entry) => PatientDiagnosis.fromJson(_map(entry))),
        ),
        notes: List.unmodifiable(
          _list(
            json['notes'],
          ).map((entry) => PatientConsultationNote.fromJson(_map(entry))),
        ),
      );
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw const FormatException('Invalid consultation response');
  }
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw const FormatException('Invalid consultation response');
  }
  return value;
}

DateTime _instant(Map<String, dynamic> json, String key) {
  final value = _string(json, key);
  if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
    throw const FormatException('Invalid consultation instant');
  }
  return DateTime.parse(value).toUtc();
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid consultation response');
  }
  return value;
}

List<dynamic> _list(Object? value) {
  if (value is! List) {
    throw const FormatException('Invalid consultation response');
  }
  return value;
}
