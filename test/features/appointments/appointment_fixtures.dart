import 'package:healthysv2/features/appointments/domain/appointment.dart';

Map<String, dynamic> appointmentJson({
  String id = 'appointment-1',
  String status = 'SCHEDULED',
}) => {
  'id': id,
  'appointmentNumber': 'APT-0001',
  'patientId': 'patient-1',
  'professionalId': 'professional-1',
  'professionalName': 'Jane Smith',
  'organizationId': 'organization-1',
  'organizationName': 'Clinic',
  'type': 'CONSULTATION',
  'scheduledStart': '2026-11-01T14:00:00Z',
  'scheduledEnd': '2026-11-01T14:30:00Z',
  'reason': 'Follow-up',
  'status': status,
  'version': 1,
  'canCancel': status == 'SCHEDULED',
  'canReschedule': status == 'SCHEDULED',
};
Map<String, dynamic> pageJson() => {
  'content': [appointmentJson()],
  'page': {
    'number': 0,
    'size': 20,
    'totalElements': 1,
    'totalPages': 1,
    'first': true,
    'last': true,
  },
};
AppointmentSummary appointment({String id = 'appointment-1'}) =>
    AppointmentSummary.fromJson(appointmentJson(id: id));
AppointmentPage page() => AppointmentPage.fromJson(pageJson());
