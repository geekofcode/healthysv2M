/// In-memory patient view. Dates from the API are calendar dates.
class PatientDashboard {
  const PatientDashboard({
    required this.person,
    required this.patient,
    this.insurances = const [],
    this.flags = const [],
    this.allergies = const [],
    this.addresses = const [],
  });
  final PatientIdentity person;
  final PatientOverview patient;
  final List<PatientInsurance> insurances;
  final List<PatientAlertFlag> flags;
  final List<PatientAllergy> allergies;
  final List<PatientAddress> addresses;
  factory PatientDashboard.fromJson(Map<String, dynamic> json) {
    final person = PatientIdentity.fromJson(_object(json['person']));
    final patient = PatientOverview.fromJson(_object(json['patient']));
    if (person.id.isEmpty ||
        patient.id.isEmpty ||
        person.id != patient.personId) {
      throw const FormatException('Inconsistent patient identity');
    }
    return PatientDashboard(
      person: person,
      patient: patient,
      insurances: _objects(
        json['insurances'],
      ).map(PatientInsurance.fromJson).toList(growable: false),
      flags: _objects(json['flags'])
          .map(PatientAlertFlag.fromJson)
          .where((f) => f.active)
          .toList(growable: false),
      allergies: _objects(json['allergies'])
          .map(PatientAllergy.fromJson)
          .where((a) => a.status.toUpperCase() == 'ACTIVE')
          .toList(growable: false),
      addresses: _objects(
        json['addresses'],
      ).map(PatientAddress.fromJson).toList(growable: false),
    );
  }
}

class PatientIdentity {
  const PatientIdentity({
    this.id = '',
    this.personNumber = '',
    this.firstName = '',
    this.middleName,
    this.lastName = '',
    this.gender,
    this.birthDate,
    this.contacts = const [],
  });
  final String id, personNumber, firstName, lastName;
  final String? middleName, gender;
  final DateTime? birthDate;
  final List<PatientContact> contacts;
  String get displayName => [
    firstName,
    middleName,
    lastName,
  ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
  factory PatientIdentity.fromJson(Map<String, dynamic> j) => PatientIdentity(
    id: _text(j['id']) ?? '',
    personNumber: _text(j['personNumber']) ?? '',
    firstName: _text(j['firstName']) ?? '',
    middleName: _text(j['middleName']),
    lastName: _text(j['lastName']) ?? '',
    gender: _text(j['gender']),
    birthDate: _date(j['birthDate']),
    contacts: _objects(
      j['contacts'],
    ).map(PatientContact.fromJson).toList(growable: false),
  );
}

class PatientContact {
  const PatientContact({
    this.id = '',
    this.type = '',
    this.value = '',
    this.primary = false,
    this.verified = false,
  });
  final String id, type, value;
  final bool primary, verified;
  factory PatientContact.fromJson(Map<String, dynamic> j) => PatientContact(
    id: _text(j['id']) ?? '',
    type: _text(j['type']) ?? '',
    value: _text(j['value']) ?? '',
    primary: j['primary'] == true,
    verified: j['verified'] == true,
  );
}

class PatientAddress {
  const PatientAddress({
    this.id = '',
    this.addressType = '',
    this.primary = false,
    this.line1 = '',
    this.line2,
    this.city = '',
    this.province,
    this.postalCode,
  });
  final String id, addressType, line1, city;
  final String? line2, province, postalCode;
  final bool primary;
  String get formatted => [
    line1,
    line2,
    city,
    province,
    postalCode,
  ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
  factory PatientAddress.fromJson(Map<String, dynamic> j) => PatientAddress(
    id: _text(j['id']) ?? '',
    addressType: _text(j['addressType']) ?? '',
    primary: j['primary'] == true,
    line1: _text(j['line1']) ?? '',
    line2: _text(j['line2']),
    city: _text(j['city']) ?? '',
    province: _text(j['province']),
    postalCode: _text(j['postalCode']),
  );
}

class PatientOverview {
  const PatientOverview({
    this.id = '',
    this.personId = '',
    this.patientNumber = '',
    this.bloodGroup,
    this.rhesus,
    this.status = '',
  });
  final String id, personId, patientNumber, status;
  final String? bloodGroup, rhesus;
  factory PatientOverview.fromJson(Map<String, dynamic> j) => PatientOverview(
    id: _text(j['id']) ?? '',
    personId: _text(j['personId']) ?? '',
    patientNumber: _text(j['patientNumber']) ?? '',
    bloodGroup: _text(j['bloodGroup']),
    rhesus: _text(j['rhesus']),
    status: _text(j['status']) ?? '',
  );
}

enum InsuranceCoverage { active, expired, upcoming, unknown }

class PatientInsurance {
  const PatientInsurance({
    this.id = '',
    this.insuranceCompanyId = '',
    this.insuranceCompanyName,
    this.policyNumber,
    this.memberNumber,
    this.startDate,
    this.endDate,
    this.primary = false,
  });
  final String id, insuranceCompanyId;
  final String? insuranceCompanyName, policyNumber, memberNumber;
  final DateTime? startDate, endDate;
  final bool primary;
  InsuranceCoverage coverageOn(DateTime now) {
    if (startDate == null && endDate == null) return InsuranceCoverage.unknown;
    final today = _day(now);
    if (startDate != null && _day(startDate!).isAfter(today)) {
      return InsuranceCoverage.upcoming;
    }
    if (endDate != null && _day(endDate!).isBefore(today)) {
      return InsuranceCoverage.expired;
    }
    return InsuranceCoverage.active;
  }

  factory PatientInsurance.fromJson(Map<String, dynamic> j) => PatientInsurance(
    id: _text(j['id']) ?? '',
    insuranceCompanyId: _text(j['insuranceCompanyId']) ?? '',
    insuranceCompanyName: _text(j['insuranceCompanyName']),
    policyNumber: _text(j['policyNumber']),
    memberNumber: _text(j['memberNumber']),
    startDate: _date(j['startDate']),
    endDate: _date(j['endDate']),
    primary: j['primary'] == true,
  );
}

class PatientAlertFlag {
  const PatientAlertFlag({
    this.id = '',
    this.flagType = '',
    this.label = '',
    this.severity,
    this.active = true,
  });
  final String id, flagType, label;
  final String? severity;
  final bool active;
  factory PatientAlertFlag.fromJson(Map<String, dynamic> j) => PatientAlertFlag(
    id: _text(j['id']) ?? '',
    flagType: _text(j['flagType']) ?? '',
    label: _text(j['label']) ?? '',
    severity: _text(j['severity']),
    active: j['active'] == true,
  );
}

class PatientAllergy {
  const PatientAllergy({
    this.id = '',
    this.allergen = '',
    this.allergyType,
    this.reaction,
    this.severity,
    this.status = 'ACTIVE',
  });
  final String id, allergen, status;
  final String? allergyType, reaction, severity;
  factory PatientAllergy.fromJson(Map<String, dynamic> j) => PatientAllergy(
    id: _text(j['id']) ?? '',
    allergen: _text(j['allergen']) ?? '',
    allergyType: _text(j['allergyType']),
    reaction: _text(j['reaction']),
    severity: _text(j['severity']),
    status: _text(j['status']) ?? '',
  );
}

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;
DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
DateTime _day(DateTime date) => DateTime.utc(date.year, date.month, date.day);
Map<String, dynamic> _object(Object? value) {
  if (value is! Map) throw const FormatException('Invalid patient contract');
  return Map<String, dynamic>.from(value);
}

Iterable<Map<String, dynamic>> _objects(Object? value) {
  if (value is! List) throw const FormatException('Missing patient collection');
  return value.map(_object);
}
