import 'patient_dashboard.dart';

/// Read-only clinical record. Free-text professional notes are not exposed.
class PatientMedicalRecord {
  const PatientMedicalRecord({
    required this.patient,
    this.allergies = const [],
    this.chronicDiseases = const [],
    this.medicalHistories = const [],
    this.surgicalHistories = const [],
    this.familyHistories = const [],
    this.disabilities = const [],
    this.flags = const [],
    this.emergencyProfile,
    this.emergencyContacts = const [],
  });
  final PatientOverview patient;
  final List<PatientAllergy> allergies;
  final List<PatientChronicDisease> chronicDiseases;
  final List<PatientMedicalHistory> medicalHistories;
  final List<PatientSurgicalHistory> surgicalHistories;
  final List<PatientFamilyHistory> familyHistories;
  final List<PatientDisability> disabilities;
  final List<PatientAlertFlag> flags;
  final PatientEmergencyProfile? emergencyProfile;
  final List<PatientEmergencyContact> emergencyContacts;

  factory PatientMedicalRecord.fromJson(Map<String, dynamic> json) {
    final patient = PatientOverview.fromJson(_object(json['patient']));
    if (patient.id.isEmpty || patient.personId.isEmpty) {
      throw const FormatException('Missing patient identity');
    }
    return PatientMedicalRecord(
      patient: patient,
      allergies: _items(json['allergies'], PatientAllergy.fromJson),
      chronicDiseases: _items(
        json['chronicDiseases'],
        PatientChronicDisease.fromJson,
      ),
      medicalHistories: _items(
        json['medicalHistories'],
        PatientMedicalHistory.fromJson,
      ),
      surgicalHistories: _items(
        json['surgicalHistories'],
        PatientSurgicalHistory.fromJson,
      ),
      familyHistories: _items(
        json['familyHistories'],
        PatientFamilyHistory.fromJson,
      ),
      disabilities: _items(json['disabilities'], PatientDisability.fromJson),
      flags: _items(
        json['flags'],
        PatientAlertFlag.fromJson,
      ).where((flag) => flag.active).toList(growable: false),
      emergencyProfile: json['emergencyProfile'] == null
          ? null
          : PatientEmergencyProfile.fromJson(_object(json['emergencyProfile'])),
      emergencyContacts: _items(
        json['emergencyContacts'],
        PatientEmergencyContact.fromJson,
      ),
    );
  }
}

class PatientChronicDisease {
  const PatientChronicDisease({
    this.id = '',
    this.diagnosisCatalogId,
    this.diagnosisCode,
    this.diagnosisLabel,
    this.diagnosedAt,
    this.status,
  });
  final String id;
  final String? diagnosisCatalogId, diagnosisCode, diagnosisLabel, status;
  final DateTime? diagnosedAt;
  factory PatientChronicDisease.fromJson(Map<String, dynamic> j) =>
      PatientChronicDisease(
        id: _text(j['id']) ?? '',
        diagnosisCatalogId: _text(j['diagnosisCatalogId']),
        diagnosisCode: _text(j['diagnosisCode']),
        diagnosisLabel: _text(j['diagnosisLabel']),
        diagnosedAt: _date(j['diagnosedAt']),
        status: _text(j['status']),
      );
}

class PatientMedicalHistory {
  const PatientMedicalHistory({
    this.id = '',
    this.condition = '',
    this.diagnosedAt,
    this.resolvedAt,
  });
  final String id, condition;
  final DateTime? diagnosedAt, resolvedAt;
  factory PatientMedicalHistory.fromJson(Map<String, dynamic> j) =>
      PatientMedicalHistory(
        id: _text(j['id']) ?? '',
        condition: _text(j['condition']) ?? '',
        diagnosedAt: _date(j['diagnosedAt']),
        resolvedAt: _date(j['resolvedAt']),
      );
}

class PatientSurgicalHistory {
  const PatientSurgicalHistory({
    this.id = '',
    this.procedureName = '',
    this.procedureDate,
    this.organizationId,
  });
  final String id, procedureName;
  final String? organizationId;
  final DateTime? procedureDate;
  factory PatientSurgicalHistory.fromJson(Map<String, dynamic> j) =>
      PatientSurgicalHistory(
        id: _text(j['id']) ?? '',
        procedureName: _text(j['procedureName']) ?? '',
        procedureDate: _date(j['procedureDate']),
        organizationId: _text(j['organizationId']),
      );
}

class PatientFamilyHistory {
  const PatientFamilyHistory({
    this.id = '',
    this.relationship,
    this.condition = '',
  });
  final String id, condition;
  final String? relationship;
  factory PatientFamilyHistory.fromJson(Map<String, dynamic> j) =>
      PatientFamilyHistory(
        id: _text(j['id']) ?? '',
        relationship: _text(j['relationship']),
        condition: _text(j['condition']) ?? '',
      );
}

class PatientDisability {
  const PatientDisability({
    this.id = '',
    this.type = '',
    this.description,
    this.startDate,
    this.status,
  });
  final String id, type;
  final String? description, status;
  final DateTime? startDate;
  factory PatientDisability.fromJson(Map<String, dynamic> j) =>
      PatientDisability(
        id: _text(j['id']) ?? '',
        type: _text(j['type']) ?? '',
        description: _text(j['description']),
        startDate: _date(j['startDate']),
        status: _text(j['status']),
      );
}

class PatientEmergencyProfile {
  const PatientEmergencyProfile({
    this.id = '',
    this.emergencyCode,
    this.bloodGroupVisible = false,
    this.allergiesVisible = false,
    this.conditionsVisible = false,
    this.medicationsVisible = false,
    this.emergencyContactVisible = false,
    this.active = false,
  });
  final String id;
  final String? emergencyCode;
  final bool bloodGroupVisible,
      allergiesVisible,
      conditionsVisible,
      medicationsVisible,
      emergencyContactVisible,
      active;
  factory PatientEmergencyProfile.fromJson(Map<String, dynamic> j) =>
      PatientEmergencyProfile(
        id: _text(j['id']) ?? '',
        emergencyCode: _text(j['emergencyCode']),
        bloodGroupVisible: _boolean(j['bloodGroupVisible']),
        allergiesVisible: _boolean(j['allergiesVisible']),
        conditionsVisible: _boolean(j['conditionsVisible']),
        medicationsVisible: _boolean(j['medicationsVisible']),
        emergencyContactVisible: _boolean(j['emergencyContactVisible']),
        active: _boolean(j['active']),
      );
}

class PatientEmergencyContact {
  const PatientEmergencyContact({
    this.id = '',
    this.firstName,
    this.lastName,
    this.relationship,
    this.phone,
    this.email,
  });
  final String id;
  final String? firstName, lastName, relationship, phone, email;
  String get displayName => [
    firstName,
    lastName,
  ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
  factory PatientEmergencyContact.fromJson(Map<String, dynamic> j) =>
      PatientEmergencyContact(
        id: _text(j['id']) ?? '',
        firstName: _text(j['firstName']),
        lastName: _text(j['lastName']),
        relationship: _text(j['relationship']),
        phone: _text(j['phone']),
        email: _text(j['email']),
      );
}

String? _text(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Invalid clinical text');
  return value.trim().isEmpty ? null : value;
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid clinical date');
  }
  final date = DateTime.parse(value);
  final normalized =
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  if (value != normalized) {
    throw const FormatException('Invalid clinical date');
  }
  return date;
}

bool _boolean(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid emergency visibility');
  }
  return value;
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map) throw const FormatException('Invalid clinical object');
  return Map<String, dynamic>.from(value);
}

List<T> _items<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) {
    throw const FormatException('Missing clinical collection');
  }
  return value.map((entry) => parse(_object(entry))).toList(growable: false);
}
