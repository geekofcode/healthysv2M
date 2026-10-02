/// Self-service appointment data. Kept in memory for the active session only.
enum AppointmentView { upcoming, past }

class AppointmentListQuery {
  const AppointmentListQuery({
    required this.view,
    this.page = 0,
    this.size = 20,
  });
  final AppointmentView view;
  final int page;
  final int size;
  @override
  bool operator ==(Object other) =>
      other is AppointmentListQuery &&
      other.view == view &&
      other.page == page &&
      other.size == size;
  @override
  int get hashCode => Object.hash(view, page, size);
}

class AppointmentSummary {
  const AppointmentSummary({
    required this.id,
    required this.appointmentNumber,
    required this.patientId,
    required this.professionalId,
    this.professionalName,
    required this.organizationId,
    this.organizationName,
    required this.type,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.reason,
    required this.status,
    required this.version,
    required this.canCancel,
    required this.canReschedule,
  });
  final String id;
  final String appointmentNumber;
  final String patientId;
  final String professionalId;
  final String? professionalName;
  final String organizationId;
  final String? organizationName;
  final String type;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final String? reason;
  final String status;
  final int version;
  final bool canCancel;
  final bool canReschedule;

  factory AppointmentSummary.fromJson(Map<String, dynamic> json) =>
      AppointmentSummary(
        id: _string(json, 'id'),
        appointmentNumber: _string(json, 'appointmentNumber'),
        patientId: _string(json, 'patientId'),
        professionalId: _string(json, 'professionalId'),
        professionalName: json['professionalName'] as String?,
        organizationId: _string(json, 'organizationId'),
        organizationName: json['organizationName'] as String?,
        type: _string(json, 'type'),
        scheduledStart: _instant(json, 'scheduledStart'),
        scheduledEnd: _instant(json, 'scheduledEnd'),
        reason: json['reason'] as String?,
        status: _string(json, 'status'),
        version: _integer(json, 'version'),
        canCancel: json['canCancel'] as bool,
        canReschedule: json['canReschedule'] as bool,
      );
}

class AppointmentPage {
  const AppointmentPage({
    required this.content,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });
  final List<AppointmentSummary> content;
  final int number;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;
  factory AppointmentPage.fromJson(Map<String, dynamic> json) {
    final page = _map(json['page']);
    return AppointmentPage(
      content: List.unmodifiable(
        _list(
          json['content'],
        ).map((entry) => AppointmentSummary.fromJson(_map(entry))),
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

class BookingOrganization {
  const BookingOrganization({required this.id, required this.name});
  final String id;
  final String name;
  factory BookingOrganization.fromJson(Map<String, dynamic> json) =>
      BookingOrganization(id: _string(json, 'id'), name: _string(json, 'name'));
}

class BookingProfessional {
  const BookingProfessional({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.professionalType,
  });
  final String id;
  final String organizationId;
  final String name;
  final String professionalType;
  factory BookingProfessional.fromJson(Map<String, dynamic> json) =>
      BookingProfessional(
        id: _string(json, 'id'),
        organizationId: _string(json, 'organizationId'),
        name: _string(json, 'name'),
        professionalType: _string(json, 'professionalType'),
      );
}

class BookingOptions {
  const BookingOptions({
    required this.organizations,
    required this.professionals,
  });
  final List<BookingOrganization> organizations;
  final List<BookingProfessional> professionals;
  factory BookingOptions.fromJson(Map<String, dynamic> json) => BookingOptions(
    organizations: List.unmodifiable(
      _list(
        json['organizations'],
      ).map((entry) => BookingOrganization.fromJson(_map(entry))),
    ),
    professionals: List.unmodifiable(
      _list(
        json['professionals'],
      ).map((entry) => BookingProfessional.fromJson(_map(entry))),
    ),
  );
}

class AppointmentSlot {
  const AppointmentSlot({
    required this.scheduledStart,
    required this.scheduledEnd,
  });
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  factory AppointmentSlot.fromJson(Map<String, dynamic> json) =>
      AppointmentSlot(
        scheduledStart: _instant(json, 'scheduledStart'),
        scheduledEnd: _instant(json, 'scheduledEnd'),
      );
}

class AvailabilityQuery {
  const AvailabilityQuery({
    required this.organizationId,
    required this.professionalId,
    required this.from,
    required this.to,
    this.excludeAppointmentId,
  });
  final String organizationId;
  final String professionalId;
  final DateTime from;
  final DateTime to;
  final String? excludeAppointmentId;
  @override
  bool operator ==(Object other) =>
      other is AvailabilityQuery &&
      other.organizationId == organizationId &&
      other.professionalId == professionalId &&
      other.from == from &&
      other.to == to &&
      other.excludeAppointmentId == excludeAppointmentId;
  @override
  int get hashCode => Object.hash(
    organizationId,
    professionalId,
    from,
    to,
    excludeAppointmentId,
  );
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw const FormatException('Invalid appointment response');
  }
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw const FormatException('Invalid appointment response');
  }
  return value;
}

DateTime _instant(Map<String, dynamic> json, String key) {
  final value = _string(json, key);
  // The backend contract uses Instant; reject ambiguous local timestamps.
  if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
    throw const FormatException('Appointment time must include a timezone');
  }
  return DateTime.parse(value).toUtc();
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid appointment response');
  }
  return value;
}

List<dynamic> _list(Object? value) {
  if (value is! List) {
    throw const FormatException('Invalid appointment response');
  }
  return value;
}
