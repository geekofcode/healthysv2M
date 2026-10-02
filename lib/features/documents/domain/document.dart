import 'dart:typed_data';

class DocumentListQuery {
  const DocumentListQuery({this.consultationId, this.page = 0, this.size = 20});
  final String? consultationId;
  final int page;
  final int size;
  @override
  bool operator ==(Object other) =>
      other is DocumentListQuery &&
      other.consultationId == consultationId &&
      other.page == page &&
      other.size == size;
  @override
  int get hashCode => Object.hash(consultationId, page, size);
}

/// No object-storage key, public link, uploader identity or checksum is exposed.
class DocumentMetadata {
  const DocumentMetadata({
    required this.id,
    required this.documentNumber,
    required this.patientId,
    this.categoryId,
    this.categoryCode,
    this.categoryName,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
    required this.status,
  });
  final String id;
  final String documentNumber;
  final String patientId;
  final String? categoryId;
  final String? categoryCode;
  final String? categoryName;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime uploadedAt;
  final String status;
  factory DocumentMetadata.fromJson(Map<String, dynamic> json) {
    final status = _string(json, 'status');
    if (status != 'ACTIVE') throw const FormatException('Inactive document');
    return DocumentMetadata(
      id: _string(json, 'id'),
      documentNumber: _string(json, 'documentNumber'),
      patientId: _string(json, 'patientId'),
      categoryId: json['categoryId'] as String?,
      categoryCode: json['categoryCode'] as String?,
      categoryName: json['categoryName'] as String?,
      fileName: _string(json, 'fileName'),
      mimeType: _string(json, 'mimeType'),
      sizeBytes: _integer(json, 'sizeBytes'),
      uploadedAt: _instant(json, 'uploadedAt'),
      status: status,
    );
  }
}

class DocumentPage {
  const DocumentPage({
    required this.content,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });
  final List<DocumentMetadata> content;
  final int number;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;
  factory DocumentPage.fromJson(Map<String, dynamic> json) {
    final page = _map(json['page']);
    final content = json['content'];
    if (content is! List) {
      throw const FormatException('Invalid document response');
    }
    return DocumentPage(
      content: List.unmodifiable(
        content.map((entry) => DocumentMetadata.fromJson(_map(entry))),
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

class DownloadedDocument {
  const DownloadedDocument({required this.metadata, required this.bytes});
  final DocumentMetadata metadata;
  final Uint8List bytes;
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw const FormatException('Invalid document response');
  }
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw const FormatException('Invalid document response');
  }
  return value;
}

DateTime _instant(Map<String, dynamic> json, String key) {
  final value = _string(json, key);
  if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
    throw const FormatException('Invalid document instant');
  }
  return DateTime.parse(value).toUtc();
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid document response');
  }
  return value;
}
