class MessagingQuery {
  const MessagingQuery({this.conversationId, this.page = 0, this.size = 20});
  final String? conversationId;
  final int page;
  final int size;
  @override
  bool operator ==(Object other) =>
      other is MessagingQuery &&
      other.conversationId == conversationId &&
      other.page == page &&
      other.size == size;
  @override
  int get hashCode => Object.hash(conversationId, page, size);
}

class MessagingPage<T> {
  const MessagingPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });
  final List<T> content;
  final int page, size, totalElements, totalPages;
  final bool last;
  factory MessagingPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) decode,
  ) {
    final meta = messagingMap(json['page']);
    return MessagingPage(
      content: List.unmodifiable(
        (json['content'] as List).map((value) => decode(messagingMap(value))),
      ),
      page: _integer(meta, 'number'),
      size: _integer(meta, 'size'),
      totalElements: _integer(meta, 'totalElements'),
      totalPages: _integer(meta, 'totalPages'),
      last: meta['last'] as bool,
    );
  }
}

class Participant {
  const Participant({
    required this.personId,
    this.displayName,
    required this.role,
    required this.status,
  });
  final String personId, status;
  final String? role;
  final String? displayName;
  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
    personId: _string(json, 'personId'),
    displayName: json['displayName'] as String?,
    role: json['role'] as String?,
    status: _string(json, 'status'),
  );
}

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.conversationNumber,
    required this.type,
    this.subject,
    required this.status,
    this.lastMessage,
    this.lastMessageAt,
    required this.unreadCount,
    required this.participants,
  });
  final String id, conversationNumber, type, status;
  final String? subject, lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final List<Participant> participants;
  factory ConversationSummary.fromJson(Map<String, dynamic> json) =>
      ConversationSummary(
        id: _string(json, 'id'),
        conversationNumber: _string(json, 'conversationNumber'),
        type: _string(json, 'type'),
        subject: json['subject'] as String?,
        status: _string(json, 'status'),
        lastMessage: json['lastMessage'] as String?,
        lastMessageAt: _optionalInstant(json, 'lastMessageAt'),
        unreadCount: _integer(json, 'unreadCount'),
        participants: _participants(json),
      );
}

class ConversationDetail {
  const ConversationDetail({
    required this.id,
    required this.conversationNumber,
    required this.type,
    this.subject,
    required this.status,
    required this.participants,
  });
  final String id, conversationNumber, type, status;
  final String? subject;
  final List<Participant> participants;
  factory ConversationDetail.fromJson(Map<String, dynamic> json) =>
      ConversationDetail(
        id: _string(json, 'id'),
        conversationNumber: _string(json, 'conversationNumber'),
        type: _string(json, 'type'),
        subject: json['subject'] as String?,
        status: _string(json, 'status'),
        participants: _participants(json),
      );
}

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderPersonId,
    this.senderName,
    required this.type,
    this.content,
    required this.sentAt,
    this.deletedAt,
    required this.documentIds,
    required this.readByCurrentUser,
    this.readByOthersCount = 0,
  });
  final String id, conversationId, senderPersonId, type;
  final String? senderName, content;
  final DateTime sentAt;
  final DateTime? deletedAt;
  final List<String> documentIds;
  final bool readByCurrentUser;
  final int readByOthersCount;
  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: _string(json, 'id'),
    conversationId: _string(json, 'conversationId'),
    senderPersonId: _string(json, 'senderPersonId'),
    senderName: json['senderName'] as String?,
    type: _string(json, 'type'),
    content: json['content'] as String?,
    sentAt: messagingInstant(json, 'sentAt'),
    deletedAt: _optionalInstant(json, 'deletedAt'),
    documentIds: List.unmodifiable(
      (json['documentIds'] as List).map((value) {
        if (value is! String || value.isEmpty) {
          throw const FormatException('Invalid document ID');
        }
        return value;
      }),
    ),
    readByCurrentUser: json['readByCurrentUser'] as bool,
    readByOthersCount: json['readByOthersCount'] == null
        ? 0
        : _integer(json, 'readByOthersCount'),
  );
}

class MessagingAttachment {
  const MessagingAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
    required this.status,
  });
  final String id, fileName, mimeType, status;
  final int sizeBytes;
  final DateTime uploadedAt;
  factory MessagingAttachment.fromJson(Map<String, dynamic> json) =>
      MessagingAttachment(
        id: _string(json, 'id'),
        fileName: _string(json, 'fileName'),
        mimeType: _string(json, 'mimeType'),
        sizeBytes: _integer(json, 'sizeBytes'),
        uploadedAt: messagingInstant(json, 'uploadedAt'),
        status: _string(json, 'status'),
      );
}

List<Participant> _participants(Map<String, dynamic> json) => List.unmodifiable(
  (json['participants'] as List).map(
    (value) => Participant.fromJson(messagingMap(value)),
  ),
);
Map<String, dynamic> messagingMap(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid messaging response');
  }
  return value;
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw const FormatException('Invalid messaging response');
  }
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw const FormatException('Invalid messaging count');
  }
  return value;
}

DateTime messagingInstant(Map<String, dynamic> json, String key) {
  final value = _string(json, key);
  if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
    throw const FormatException('Invalid messaging instant');
  }
  return DateTime.parse(value).toUtc();
}

DateTime? _optionalInstant(Map<String, dynamic> json, String key) =>
    json[key] == null ? null : messagingInstant(json, key);

class MessagingAttachmentQuery {
  const MessagingAttachmentQuery(this.conversationId, this.documentId);
  final String conversationId, documentId;
  @override
  bool operator ==(Object other) =>
      other is MessagingAttachmentQuery &&
      other.conversationId == conversationId &&
      other.documentId == documentId;
  @override
  int get hashCode => Object.hash(conversationId, documentId);
}

class MessagingRecipient {
  const MessagingRecipient({
    required this.personId,
    required this.displayName,
    required this.professionalId,
  });
  final String personId, displayName, professionalId;
  factory MessagingRecipient.fromJson(Map<String, dynamic> json) =>
      MessagingRecipient(
        personId: _string(json, 'personId'),
        displayName: json['displayName'] as String? ?? '',
        professionalId: _string(json, 'professionalId'),
      );
}
