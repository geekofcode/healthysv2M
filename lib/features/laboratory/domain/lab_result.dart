class LabResultListQuery {
  const LabResultListQuery({this.page = 0, this.size = 20});
  final int page;
  final int size;
  @override
  bool operator ==(Object other) =>
      other is LabResultListQuery && other.page == page && other.size == size;
  @override
  int get hashCode => Object.hash(page, size);
}

class LabResultSummary {
  const LabResultSummary({
    required this.id,
    required this.resultNumber,
    required this.labOrderId,
    required this.orderNumber,
    required this.patientId,
    required this.laboratoryOrganizationId,
    required this.status,
    this.laboratoryName,
    required this.orderedAt,
    required this.validatedAt,
    this.performedAt,
  });
  final String id;
  final String resultNumber;
  final String labOrderId;
  final String orderNumber;
  final String patientId;
  final String? laboratoryOrganizationId;
  final String status;
  final String? laboratoryName;
  final DateTime orderedAt;
  final DateTime validatedAt;
  final DateTime? performedAt;
  factory LabResultSummary.fromJson(Map<String, dynamic> json) {
    if (json['status'] != 'FINAL') {
      throw const FormatException('Unvalidated laboratory result');
    }
    return LabResultSummary(
      id: _requiredString(json, 'id'),
      resultNumber: _requiredString(json, 'resultNumber'),
      labOrderId: _requiredString(json, 'labOrderId'),
      orderNumber: _requiredString(json, 'orderNumber'),
      patientId: _requiredString(json, 'patientId'),
      laboratoryOrganizationId: _optionalString(
        json,
        'laboratoryOrganizationId',
      ),
      status: _requiredString(json, 'status'),
      laboratoryName: _optionalString(json, 'laboratoryName'),
      orderedAt: _instant(json, 'orderedAt', required: true)!,
      validatedAt: _instant(json, 'validatedAt', required: true)!,
      performedAt: _instant(json, 'performedAt'),
    );
  }
}

class LabResultItem {
  const LabResultItem({
    required this.id,
    required this.labOrderItemId,
    required this.examCode,
    required this.examName,
    required this.parameter,
    required this.value,
    this.parameterCatalogId,
    this.unit,
    this.interpretation,
    this.abnormalFlag,
    this.referenceMin,
    this.referenceMax,
  });
  final String id;
  final String labOrderItemId;
  final String examCode;
  final String examName;
  final String parameter;
  final String value;
  final String? parameterCatalogId;
  final String? unit;
  final String? interpretation;
  final String? abnormalFlag;
  final String? referenceMin;
  final String? referenceMax;
  factory LabResultItem.fromJson(Map<String, dynamic> json) {
    return LabResultItem(
      id: _requiredString(json, 'id'),
      labOrderItemId: _requiredString(json, 'labOrderItemId'),
      examCode: _requiredString(json, 'examCode'),
      examName: _requiredString(json, 'examName'),
      parameter: _requiredString(json, 'parameter'),
      value: _requiredString(json, 'value'),
      parameterCatalogId: _optionalString(json, 'parameterCatalogId'),
      unit: _optionalString(json, 'unit'),
      interpretation: _optionalString(json, 'interpretation'),
      abnormalFlag: _optionalString(json, 'abnormalFlag'),
      referenceMin: _decimalString(json, 'referenceMin'),
      referenceMax: _decimalString(json, 'referenceMax'),
    );
  }
}

class LabResultDetail {
  const LabResultDetail({required this.result, required this.items});
  final LabResultSummary result;
  final List<LabResultItem> items;
  factory LabResultDetail.fromJson(Map<String, dynamic> json) {
    return LabResultDetail(
      result: LabResultSummary.fromJson(_object(json['result'])),
      items: _objects(json['items'], LabResultItem.fromJson),
    );
  }
}

class LabResultPage {
  const LabResultPage({
    required this.content,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });
  final List<LabResultSummary> content;
  final int number, size, totalElements, totalPages;
  final bool first, last;
  factory LabResultPage.fromJson(Map<String, dynamic> json) {
    final page = _object(json['page']);
    return LabResultPage(
      content: _objects(json['content'], LabResultSummary.fromJson),
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
