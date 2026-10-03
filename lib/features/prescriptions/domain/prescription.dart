class PrescriptionListQuery {
  const PrescriptionListQuery({this.page = 0, this.size = 20});
  final int page;
  final int size;
  @override
  bool operator ==(Object other) =>
      other is PrescriptionListQuery &&
      other.page == page &&
      other.size == size;
  @override
  int get hashCode => Object.hash(page, size);
}

class PrescriptionSummary {
  const PrescriptionSummary({
    required this.id,
    required this.prescriptionNumber,
    required this.patientId,
    required this.prescriberId,
    required this.organizationId,
    required this.status,
    this.consultationId,
    this.prescriberName,
    this.organizationName,
    required this.prescribedAt,
    this.expiresAt,
    required this.expired,
  });
  final String id;
  final String prescriptionNumber;
  final String patientId;
  final String prescriberId;
  final String? organizationId;
  final String status;
  final String? consultationId;
  final String? prescriberName;
  final String? organizationName;
  final DateTime prescribedAt;
  final DateTime? expiresAt;
  final bool expired;
  factory PrescriptionSummary.fromJson(Map<String, dynamic> json) {
    if (!const {
      'ACTIVE',
      'PARTIALLY_DISPENSED',
      'DISPENSED',
      'CANCELLED',
    }.contains(json['status'])) {
      throw const FormatException('Invalid prescription status');
    }
    return PrescriptionSummary(
      id: _requiredString(json, 'id'),
      prescriptionNumber: _requiredString(json, 'prescriptionNumber'),
      patientId: _requiredString(json, 'patientId'),
      prescriberId: _requiredString(json, 'prescriberId'),
      organizationId: _optionalString(json, 'organizationId'),
      status: _requiredString(json, 'status'),
      consultationId: _optionalString(json, 'consultationId'),
      prescriberName: _optionalString(json, 'prescriberName'),
      organizationName: _optionalString(json, 'organizationName'),
      prescribedAt: _instant(json, 'prescribedAt', required: true)!,
      expiresAt: _instant(json, 'expiresAt'),
      expired: json['expired'] as bool,
    );
  }
}

class PrescriptionItem {
  const PrescriptionItem({
    required this.id,
    required this.medicationName,
    this.medicationCatalogId,
    this.medicationCode,
    this.genericName,
    this.form,
    this.strength,
    this.dosage,
    this.frequency,
    this.route,
    this.duration,
    this.instructions,
    this.quantity,
    this.quantityDispensed,
    this.quantityRemaining,
  });
  final String id;
  final String medicationName;
  final String? medicationCatalogId;
  final String? medicationCode;
  final String? genericName;
  final String? form;
  final String? strength;
  final String? dosage;
  final String? frequency;
  final String? route;
  final String? duration;
  final String? instructions;
  final String? quantity;
  final String? quantityDispensed;
  final String? quantityRemaining;
  factory PrescriptionItem.fromJson(Map<String, dynamic> json) {
    return PrescriptionItem(
      id: _requiredString(json, 'id'),
      medicationName: _requiredString(json, 'medicationName'),
      medicationCatalogId: _optionalString(json, 'medicationCatalogId'),
      medicationCode: _optionalString(json, 'medicationCode'),
      genericName: _optionalString(json, 'genericName'),
      form: _optionalString(json, 'form'),
      strength: _optionalString(json, 'strength'),
      dosage: _optionalString(json, 'dosage'),
      frequency: _optionalString(json, 'frequency'),
      route: _optionalString(json, 'route'),
      duration: _optionalString(json, 'duration'),
      instructions: _optionalString(json, 'instructions'),
      quantity: _decimalString(json, 'quantity'),
      quantityDispensed: _decimalString(json, 'quantityDispensed'),
      quantityRemaining: _decimalString(json, 'quantityRemaining'),
    );
  }
}

class DispensationItem {
  const DispensationItem({
    required this.id,
    required this.prescriptionItemId,
    required this.medicationName,
    this.quantityDispensed,
  });
  final String id;
  final String prescriptionItemId;
  final String medicationName;
  final String? quantityDispensed;
  factory DispensationItem.fromJson(Map<String, dynamic> json) {
    return DispensationItem(
      id: _requiredString(json, 'id'),
      prescriptionItemId: _requiredString(json, 'prescriptionItemId'),
      medicationName: _requiredString(json, 'medicationName'),
      quantityDispensed: _decimalString(json, 'quantityDispensed'),
    );
  }
}

class PrescriptionDispensation {
  const PrescriptionDispensation({
    required this.id,
    required this.dispenseNumber,
    required this.pharmacyOrganizationId,
    required this.status,
    this.pharmacyName,
    required this.dispensedAt,
    required this.items,
  });
  final String id;
  final String dispenseNumber;
  final String pharmacyOrganizationId;
  final String status;
  final String? pharmacyName;
  final DateTime dispensedAt;
  final List<DispensationItem> items;
  factory PrescriptionDispensation.fromJson(Map<String, dynamic> json) {
    return PrescriptionDispensation(
      id: _requiredString(json, 'id'),
      dispenseNumber: _requiredString(json, 'dispenseNumber'),
      pharmacyOrganizationId: _requiredString(json, 'pharmacyOrganizationId'),
      status: _requiredString(json, 'status'),
      pharmacyName: _optionalString(json, 'pharmacyName'),
      dispensedAt: _instant(json, 'dispensedAt', required: true)!,
      items: _objects(json['items'], DispensationItem.fromJson),
    );
  }
}

class PrescriptionDetail {
  const PrescriptionDetail({
    required this.prescription,
    required this.items,
    required this.dispensations,
  });
  final PrescriptionSummary prescription;
  final List<PrescriptionItem> items;
  final List<PrescriptionDispensation> dispensations;
  factory PrescriptionDetail.fromJson(Map<String, dynamic> json) {
    return PrescriptionDetail(
      prescription: PrescriptionSummary.fromJson(_object(json['prescription'])),
      items: _objects(json['items'], PrescriptionItem.fromJson),
      dispensations: _objects(
        json['dispensations'],
        PrescriptionDispensation.fromJson,
      ),
    );
  }
}

class PrescriptionPage {
  const PrescriptionPage({
    required this.content,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });
  final List<PrescriptionSummary> content;
  final int number, size, totalElements, totalPages;
  final bool first, last;
  factory PrescriptionPage.fromJson(Map<String, dynamic> json) {
    final page = _object(json['page']);
    return PrescriptionPage(
      content: _objects(json['content'], PrescriptionSummary.fromJson),
      number: _integer(page, 'number'),
      size: _integer(page, 'size'),
      totalElements: _integer(page, 'totalElements'),
      totalPages: _integer(page, 'totalPages'),
      first: page['first'] as bool,
      last: page['last'] as bool,
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw const FormatException('Invalid patient response');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) =>
    json[key] as String?;
String? _decimalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! num || !value.isFinite) {
    throw const FormatException('Invalid clinical numeric value');
  }
  return value.toString();
}

DateTime? _instant(
  Map<String, dynamic> json,
  String key, {
  bool required = false,
}) {
  final value = json[key];
  if (value == null && !required) {
    return null;
  }
  if (value is! String || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
    throw const FormatException('Invalid patient instant');
  }
  return DateTime.parse(value).toUtc();
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid patient response');
  }
  return value;
}

List<T> _objects<T>(Object? value, T Function(Map<String, dynamic>) decode) {
  if (value is! List) {
    throw const FormatException('Invalid patient response');
  }
  return List.unmodifiable(value.map((entry) => decode(_object(entry))));
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw const FormatException('Invalid pagination');
  }
  return value;
}
