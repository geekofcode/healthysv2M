class NotificationQuery {
  const NotificationQuery({
    this.page = 0,
    this.size = 20,
    this.unreadOnly = false,
  });
  final int page;
  final int size;
  final bool unreadOnly;
  @override
  bool operator ==(Object other) =>
      other is NotificationQuery &&
      page == other.page &&
      size == other.size &&
      unreadOnly == other.unreadOnly;
  @override
  int get hashCode => Object.hash(page, size, unreadOnly);
}

bool notificationUuid(String? value) =>
    value != null &&
    RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);

class HealthysNotification {
  const HealthysNotification({
    required this.id,
    required this.type,
    this.title,
    required this.body,
    this.resourceType,
    this.resourceId,
    this.actionUrl,
    required this.priority,
    required this.createdAt,
    this.expiresAt,
    required this.status,
    this.readAt,
    required this.read,
  });
  factory HealthysNotification.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    if (!notificationUuid(id)) {
      throw const FormatException('Invalid notification id');
    }
    return HealthysNotification(
      id: id,
      type: json['type'] as String,
      title: json['title'] as String?,
      body: json['body'] as String,
      resourceType: json['resourceType'] as String?,
      resourceId: json['resourceId'] as String?,
      actionUrl: json['actionUrl'] as String?,
      priority: json['priority'] as String,
      createdAt: _instant(json['createdAt'])!,
      expiresAt: _instant(json['expiresAt']),
      status: json['status'] as String,
      readAt: _instant(json['readAt']),
      read: json['read'] as bool,
    );
  }
  final String id, type, body, priority, status;
  final String? title, resourceType, resourceId, actionUrl;
  final DateTime createdAt;
  final DateTime? expiresAt, readAt;
  final bool read;
}

DateTime? _instant(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value as String;
  if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(text)) {
    throw const FormatException('Timezone required');
  }
  return DateTime.parse(text);
}

/// Only resource identities from an authenticated recipient response are used.
/// Server action URLs and untrusted push payload URLs are never followed.
String notificationDestination(HealthysNotification notification) {
  if (!notificationUuid(notification.resourceId)) {
    return '/notifications';
  }
  final id = notification.resourceId!;
  return switch (notification.resourceType?.toUpperCase()) {
    'APPOINTMENT' => '/appointments/$id',
    'CONSULTATION' => '/consultations/$id',
    'DOCUMENT' => '/documents/$id/view',
    'LAB_RESULT' => '/lab-results/$id',
    'PRESCRIPTION' => '/prescriptions/$id',
    'CONVERSATION' => '/messages/$id',
    'PREGNANCY' => '/maternal-child/pregnancies/$id',
    'CHILD' => '/maternal-child/children/$id',
    _ => '/notifications',
  };
}

class NotificationPage {
  const NotificationPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });
  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final page = json['page'] as Map<String, dynamic>;
    return NotificationPage(
      content: List.unmodifiable(
        (json['content'] as List).map(
          (value) =>
              HealthysNotification.fromJson(value as Map<String, dynamic>),
        ),
      ),
      page: page['number'] as int,
      size: page['size'] as int,
      totalElements: page['totalElements'] as int,
      totalPages: page['totalPages'] as int,
      last: page['last'] as bool,
    );
  }
  final List<HealthysNotification> content;
  final int page, size, totalElements, totalPages;
  final bool last;
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.inAppEnabled,
    required this.emailEnabled,
    required this.smsEnabled,
    required this.pushEnabled,
    this.quietHoursStart,
    this.quietHoursEnd,
    required this.locale,
  });
  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        inAppEnabled: json['inAppEnabled'] as bool,
        emailEnabled: json['emailEnabled'] as bool,
        smsEnabled: json['smsEnabled'] as bool,
        pushEnabled: json['pushEnabled'] as bool,
        quietHoursStart: json['quietHoursStart'] as String?,
        quietHoursEnd: json['quietHoursEnd'] as String?,
        locale: json['locale'] as String,
      );
  final bool inAppEnabled, emailEnabled, smsEnabled, pushEnabled;
  final String? quietHoursStart, quietHoursEnd;
  final String locale;
  NotificationPreferences copyWith({
    bool? inAppEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
    bool? pushEnabled,
    String? locale,
  }) => NotificationPreferences(
    inAppEnabled: inAppEnabled ?? this.inAppEnabled,
    emailEnabled: emailEnabled ?? this.emailEnabled,
    smsEnabled: smsEnabled ?? this.smsEnabled,
    pushEnabled: pushEnabled ?? this.pushEnabled,
    quietHoursStart: quietHoursStart,
    quietHoursEnd: quietHoursEnd,
    locale: locale ?? this.locale,
  );
  Map<String, Object?> toJson() => {
    'inAppEnabled': inAppEnabled,
    'emailEnabled': emailEnabled,
    'smsEnabled': smsEnabled,
    'pushEnabled': pushEnabled,
    'quietHoursStart': quietHoursStart,
    'quietHoursEnd': quietHoursEnd,
    'locale': locale,
  };
}
