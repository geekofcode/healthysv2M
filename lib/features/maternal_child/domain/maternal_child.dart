/// Calendar dates remain ISO strings; measurements preserve absent values.
class MaternalChildListQuery {
  const MaternalChildListQuery({this.page = 0, this.size = 20});
  final int page, size;
  @override
  bool operator ==(Object other) =>
      other is MaternalChildListQuery &&
      other.page == page &&
      other.size == size;
  @override
  int get hashCode => Object.hash(page, size);
}

class PregnancySummary {
  const PregnancySummary({
    required this.id,
    required this.pregnancyNumber,
    required this.motherPatientId,
    this.expectedDeliveryDate,
    required this.status,
    required this.createdAt,
  });
  final String id;
  final String pregnancyNumber;
  final String motherPatientId;
  final String? expectedDeliveryDate;
  final String status;
  final DateTime createdAt;
  factory PregnancySummary.fromJson(Map<String, dynamic> json) =>
      PregnancySummary(
        id: _s(json['id'], optional: false)!,
        pregnancyNumber: _s(json['pregnancyNumber'], optional: false)!,
        motherPatientId: _s(json['motherPatientId'], optional: false)!,
        expectedDeliveryDate: _d(json['expectedDeliveryDate'], optional: true),
        status: _s(json['status'], optional: false)!,
        createdAt: _t(json['createdAt'], optional: false)!,
      );
}

class PrenatalVisit {
  const PrenatalVisit({
    required this.id,
    required this.visitDate,
    this.gestationalAgeWeeks,
    this.weightKg,
    this.systolicPressure,
    this.diastolicPressure,
    this.fetalHeartRate,
  });
  final String id;
  final DateTime visitDate;
  final int? gestationalAgeWeeks;
  final String? weightKg;
  final int? systolicPressure;
  final int? diastolicPressure;
  final int? fetalHeartRate;
  factory PrenatalVisit.fromJson(Map<String, dynamic> json) => PrenatalVisit(
    id: _s(json['id'], optional: false)!,
    visitDate: _t(json['visitDate'], optional: false)!,
    gestationalAgeWeeks: _i(json['gestationalAgeWeeks'], optional: true),
    weightKg: _n(json['weightKg'], optional: true),
    systolicPressure: _i(json['systolicPressure'], optional: true),
    diastolicPressure: _i(json['diastolicPressure'], optional: true),
    fetalHeartRate: _i(json['fetalHeartRate'], optional: true),
  );
}

class NewbornSummary {
  const NewbornSummary({
    required this.id,
    required this.childPatientId,
    this.birthOrder,
    this.birthWeightKg,
    this.birthHeightCm,
    this.headCircumferenceCm,
    this.apgar1,
    this.apgar5,
    required this.status,
  });
  final String id;
  final String childPatientId;
  final int? birthOrder;
  final String? birthWeightKg;
  final String? birthHeightCm;
  final String? headCircumferenceCm;
  final int? apgar1;
  final int? apgar5;
  final String status;
  factory NewbornSummary.fromJson(Map<String, dynamic> json) => NewbornSummary(
    id: _s(json['id'], optional: false)!,
    childPatientId: _s(json['childPatientId'], optional: false)!,
    birthOrder: _i(json['birthOrder'], optional: true),
    birthWeightKg: _n(json['birthWeightKg'], optional: true),
    birthHeightCm: _n(json['birthHeightCm'], optional: true),
    headCircumferenceCm: _n(json['headCircumferenceCm'], optional: true),
    apgar1: _i(json['apgar1'], optional: true),
    apgar5: _i(json['apgar5'], optional: true),
    status: _s(json['status'], optional: false)!,
  );
}

class BirthSummary {
  const BirthSummary({
    required this.id,
    required this.deliveryDate,
    required this.deliveryType,
    required this.newborns,
  });
  final String id;
  final DateTime deliveryDate;
  final String deliveryType;
  final List<NewbornSummary> newborns;
  factory BirthSummary.fromJson(Map<String, dynamic> json) => BirthSummary(
    id: _s(json['id'], optional: false)!,
    deliveryDate: _t(json['deliveryDate'], optional: false)!,
    deliveryType: _s(json['deliveryType'], optional: false)!,
    newborns: _list(json['newborns'], NewbornSummary.fromJson),
  );
}

class PregnancyDetail {
  const PregnancyDetail({
    required this.pregnancy,
    this.estimatedConceptionDate,
    this.lastMenstrualPeriod,
    required this.prenatalVisits,
    this.delivery,
  });
  final PregnancySummary pregnancy;
  final String? estimatedConceptionDate;
  final String? lastMenstrualPeriod;
  final List<PrenatalVisit> prenatalVisits;
  final BirthSummary? delivery;
  factory PregnancyDetail.fromJson(Map<String, dynamic> json) =>
      PregnancyDetail(
        pregnancy: PregnancySummary.fromJson(_object(json['pregnancy'])),
        estimatedConceptionDate: _d(
          json['estimatedConceptionDate'],
          optional: true,
        ),
        lastMenstrualPeriod: _d(json['lastMenstrualPeriod'], optional: true),
        prenatalVisits: _list(json['prenatalVisits'], PrenatalVisit.fromJson),
        delivery: json['delivery'] == null
            ? null
            : BirthSummary.fromJson(_object(json['delivery'])),
      );
}

class ChildSummary {
  const ChildSummary({
    required this.id,
    required this.childPatientId,
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.sex,
    required this.status,
    required this.createdAt,
  });
  final String id;
  final String childPatientId;
  final String? firstName;
  final String? lastName;
  final String? dateOfBirth;
  final String? sex;
  final String status;
  final DateTime createdAt;
  factory ChildSummary.fromJson(Map<String, dynamic> json) => ChildSummary(
    id: _s(json['id'], optional: false)!,
    childPatientId: _s(json['childPatientId'], optional: false)!,
    firstName: _s(json['firstName'], optional: true),
    lastName: _s(json['lastName'], optional: true),
    dateOfBirth: _d(json['dateOfBirth'], optional: true),
    sex: _s(json['sex'], optional: true),
    status: _s(json['status'], optional: false)!,
    createdAt: _t(json['createdAt'], optional: false)!,
  );
}

class ChildBirth {
  const ChildBirth({
    required this.deliveryDate,
    required this.deliveryType,
    this.birthOrder,
    this.birthWeightKg,
    this.birthHeightCm,
    this.headCircumferenceCm,
    this.apgar1,
    this.apgar5,
    required this.status,
  });
  final DateTime deliveryDate;
  final String deliveryType;
  final int? birthOrder;
  final String? birthWeightKg;
  final String? birthHeightCm;
  final String? headCircumferenceCm;
  final int? apgar1;
  final int? apgar5;
  final String status;
  factory ChildBirth.fromJson(Map<String, dynamic> json) => ChildBirth(
    deliveryDate: _t(json['deliveryDate'], optional: false)!,
    deliveryType: _s(json['deliveryType'], optional: false)!,
    birthOrder: _i(json['birthOrder'], optional: true),
    birthWeightKg: _n(json['birthWeightKg'], optional: true),
    birthHeightCm: _n(json['birthHeightCm'], optional: true),
    headCircumferenceCm: _n(json['headCircumferenceCm'], optional: true),
    apgar1: _i(json['apgar1'], optional: true),
    apgar5: _i(json['apgar5'], optional: true),
    status: _s(json['status'], optional: false)!,
  );
}

class Vaccination {
  const Vaccination({
    required this.id,
    this.vaccineCatalogId,
    this.vaccineCode,
    this.vaccineName,
    this.doseNumber,
    this.administeredAt,
    this.nextDueDate,
    required this.status,
  });
  final String id;
  final String? vaccineCatalogId;
  final String? vaccineCode;
  final String? vaccineName;
  final int? doseNumber;
  final DateTime? administeredAt;
  final String? nextDueDate;
  final String status;
  factory Vaccination.fromJson(Map<String, dynamic> json) => Vaccination(
    id: _s(json['id'], optional: false)!,
    vaccineCatalogId: _s(json['vaccineCatalogId'], optional: true),
    vaccineCode: _s(json['vaccineCode'], optional: true),
    vaccineName: _s(json['vaccineName'], optional: true),
    doseNumber: _i(json['doseNumber'], optional: true),
    administeredAt: _t(json['administeredAt'], optional: true),
    nextDueDate: _d(json['nextDueDate'], optional: true),
    status: _s(json['status'], optional: false)!,
  );
}

class GrowthMeasurement {
  const GrowthMeasurement({
    required this.id,
    required this.measuredAt,
    this.weightKg,
    this.heightCm,
    this.headCircumferenceCm,
    this.bmi,
  });
  final String id;
  final DateTime measuredAt;
  final String? weightKg;
  final String? heightCm;
  final String? headCircumferenceCm;
  final String? bmi;
  factory GrowthMeasurement.fromJson(Map<String, dynamic> json) =>
      GrowthMeasurement(
        id: _s(json['id'], optional: false)!,
        measuredAt: _t(json['measuredAt'], optional: false)!,
        weightKg: _n(json['weightKg'], optional: true),
        heightCm: _n(json['heightCm'], optional: true),
        headCircumferenceCm: _n(json['headCircumferenceCm'], optional: true),
        bmi: _n(json['bmi'], optional: true),
      );
}

class ChildDetail {
  const ChildDetail({
    required this.child,
    this.birth,
    required this.vaccinations,
    required this.growthMeasurements,
  });
  final ChildSummary child;
  final ChildBirth? birth;
  final List<Vaccination> vaccinations;
  final List<GrowthMeasurement> growthMeasurements;
  factory ChildDetail.fromJson(Map<String, dynamic> json) => ChildDetail(
    child: ChildSummary.fromJson(_object(json['child'])),
    birth: json['birth'] == null
        ? null
        : ChildBirth.fromJson(_object(json['birth'])),
    vaccinations: _list(json['vaccinations'], Vaccination.fromJson),
    growthMeasurements: _list(
      json['growthMeasurements'],
      GrowthMeasurement.fromJson,
    ),
  );
}

class MaternalPage<T> {
  const MaternalPage({
    required this.content,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });
  final List<T> content;
  final int number, size, totalElements, totalPages;
  final bool first, last;
  static MaternalPage<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) decode,
  ) {
    final page = _object(json['page']);
    return MaternalPage(
      content: _list(json['content'], decode),
      number: _pageInteger(page['number']),
      size: _pageInteger(page['size']),
      totalElements: _pageInteger(page['totalElements']),
      totalPages: _pageInteger(page['totalPages']),
      first: page['first'] as bool,
      last: page['last'] as bool,
    );
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid notebook object');
  }
  return value;
}

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) decode) {
  if (value is! List) {
    throw const FormatException('Invalid notebook list');
  }
  return List.unmodifiable(value.map((entry) => decode(_object(entry))));
}

String? _s(Object? value, {bool optional = false}) {
  if (value == null && optional) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Invalid notebook string');
  }
  return value;
}

int? _i(Object? value, {bool optional = false}) {
  if (value == null && optional) {
    return null;
  }
  if (value is! int) {
    throw const FormatException('Invalid notebook integer');
  }
  return value;
}

int _pageInteger(Object? value) {
  final result = _i(value)!;
  if (result < 0) {
    throw const FormatException('Invalid notebook pagination');
  }
  return result;
}

String? _n(Object? value, {bool optional = false}) {
  if (value == null && optional) {
    return null;
  }
  if (value is! num || !value.isFinite) {
    throw const FormatException('Invalid notebook measurement');
  }
  return value.toString();
}

String? _d(Object? value, {bool optional = false}) {
  final date = _s(value, optional: optional);
  if (date == null) {
    return null;
  }
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
    throw const FormatException('Invalid notebook date');
  }
  final parsed = DateTime.parse(date);
  if (parsed.toIso8601String().substring(0, 10) != date) {
    throw const FormatException('Invalid notebook date');
  }
  return date;
}

DateTime? _t(Object? value, {bool optional = false}) {
  final instant = _s(value, optional: optional);
  if (instant == null) {
    return null;
  }
  if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(instant)) {
    throw const FormatException('Invalid notebook instant');
  }
  return DateTime.parse(instant).toUtc();
}
