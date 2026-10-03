class VideoParticipant {
  const VideoParticipant({
    required this.personId,
    required this.role,
    this.displayName,
  });
  final String personId;
  final String role;
  final String? displayName;
  factory VideoParticipant.fromJson(Map<String, dynamic> json) =>
      VideoParticipant(
        personId: _uuid(json['personId']),
        role: json['role'] as String,
        displayName: json['displayName'] as String?,
      );
}

class WaitingRoomEntry {
  const WaitingRoomEntry({required this.patientId, required this.status});
  final String patientId;
  final String status;
  factory WaitingRoomEntry.fromJson(Map<String, dynamic> json) =>
      WaitingRoomEntry(
        patientId: _uuid(json['patientId']),
        status: json['status'] as String,
      );
}

class VideoSession {
  const VideoSession({
    required this.id,
    required this.sessionNumber,
    required this.status,
    this.appointmentId,
    this.consultationId,
    this.scheduledStart,
    this.participants = const [],
    this.waitingRoom = const [],
    this.canJoin = false,
  });
  final String id;
  final String sessionNumber;
  final String status;
  final String? appointmentId;
  final String? consultationId;
  final DateTime? scheduledStart;
  final List<VideoParticipant> participants;
  final List<WaitingRoomEntry> waitingRoom;
  bool get isEnded => {'COMPLETED', 'CANCELLED', 'ENDED'}.contains(status);
  // The patient-scoped backend response is authoritative for admission.
  final bool canJoin;
  factory VideoSession.fromJson(Map<String, dynamic> json) => VideoSession(
    id: _uuid(json['id']),
    sessionNumber: json['sessionNumber'] as String,
    status: json['status'] as String,
    canJoin: json['canJoin'] == true,
    appointmentId: json['appointmentId'] == null
        ? null
        : _uuid(json['appointmentId']),
    consultationId: json['consultationId'] == null
        ? null
        : _uuid(json['consultationId']),
    scheduledStart: json['scheduledStart'] == null
        ? null
        : _instant(json['scheduledStart']),
    participants: List.unmodifiable(
      (json['participants'] as List? ?? []).map(
        (e) => VideoParticipant.fromJson(e as Map<String, dynamic>),
      ),
    ),
    waitingRoom: List.unmodifiable(
      (json['waitingRoom'] as List? ?? []).map(
        (e) => WaitingRoomEntry.fromJson(e as Map<String, dynamic>),
      ),
    ),
  );
}

class VideoSessionToken {
  const VideoSessionToken({
    required this.serverUrl,
    required this.token,
    required this.roomName,
    required this.expiresAt,
  });
  final String serverUrl;
  final String token;
  final String roomName;
  final DateTime expiresAt;
  factory VideoSessionToken.fromJson(Map<String, dynamic> json) =>
      VideoSessionToken(
        serverUrl: json['serverUrl'] as String,
        token: json['token'] as String,
        roomName: json['roomName'] as String,
        expiresAt: _instant(json['expiresAt']),
      );
  @override
  String toString() => 'VideoSessionToken(redacted)';
}

class VideoSessionQuery {
  const VideoSessionQuery({this.page = 0, this.size = 20});
  final int page;
  final int size;
  @override
  bool operator ==(Object other) =>
      other is VideoSessionQuery && other.page == page && other.size == size;
  @override
  int get hashCode => Object.hash(page, size);
}

class VideoSessionPage {
  const VideoSessionPage({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.number,
    required this.size,
  });
  final List<VideoSession> content;
  final int totalElements;
  final int totalPages;
  final int number;
  final int size;
  factory VideoSessionPage.fromJson(Map<String, dynamic> json) =>
      VideoSessionPage(
        content: List.unmodifiable(
          (json['content'] as List).map(
            (e) => VideoSession.fromJson(e as Map<String, dynamic>),
          ),
        ),
        totalElements:
            (json['page'] as Map<String, dynamic>)['totalElements'] as int,
        totalPages: (json['page'] as Map<String, dynamic>)['totalPages'] as int,
        number: (json['page'] as Map<String, dynamic>)['number'] as int,
        size: (json['page'] as Map<String, dynamic>)['size'] as int,
      );
}

String _uuid(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value)) {
    throw const FormatException('Invalid video identity');
  }
  return value;
}

DateTime _instant(Object? value) {
  if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw const FormatException('Invalid video timestamp');
  }
  return DateTime.parse(value).toUtc();
}
