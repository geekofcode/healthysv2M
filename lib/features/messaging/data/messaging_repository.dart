import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../documents/data/document_repository.dart';
import '../../documents/domain/document.dart';
import '../domain/messaging.dart';

abstract interface class MessagingRepository {
  Future<List<MessagingRecipient>> recipients({CancelToken? cancelToken});
  Future<ConversationDetail> create(
    String recipientPersonId,
    String subject, {
    CancelToken? cancelToken,
  });
  Future<MessagingPage<ConversationSummary>> conversations(
    MessagingQuery query, {
    CancelToken? cancelToken,
  });
  Future<ConversationDetail> conversation(
    String id, {
    CancelToken? cancelToken,
  });
  Future<MessagingPage<Message>> messages(
    MessagingQuery query, {
    CancelToken? cancelToken,
  });
  Future<Message> send(
    String conversationId,
    String content, {
    List<String> documentIds = const [],
    CancelToken? cancelToken,
  });
  Future<void> markRead(String messageId, {CancelToken? cancelToken});
  Future<MessagingAttachment> upload(
    String conversationId,
    String fileName,
    Uint8List bytes, {
    CancelToken? cancelToken,
  });
  Future<MessagingAttachment> attachment(
    String conversationId,
    String documentId, {
    CancelToken? cancelToken,
  });
  Future<DownloadedDocument> download(
    String conversationId,
    String documentId, {
    CancelToken? cancelToken,
  });
}

class DioMessagingRepository implements MessagingRepository {
  DioMessagingRepository(this.dio);
  final Dio dio;
  String _conversation(String id) => 'conversations/${Uri.encodeComponent(id)}';
  String _attachment(String conversationId, String documentId) =>
      '${_conversation(conversationId)}/attachments/${Uri.encodeComponent(documentId)}';
  @override
  Future<List<MessagingRecipient>> recipients({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dio.get<Object?>(
        'conversations/recipients',
        cancelToken: cancelToken,
      );
      return List.unmodifiable(
        (response.data as List).map(
          (value) => MessagingRecipient.fromJson(messagingMap(value)),
        ),
      );
    } on DioException catch (error) {
      if (error.error case final AppException mapped) {
        throw mapped;
      }
      throw AppException.fromDio(error);
    } on FormatException {
      throw _invalid;
    } on TypeError {
      throw _invalid;
    }
  }

  @override
  Future<ConversationDetail> create(
    String recipientPersonId,
    String subject, {
    CancelToken? cancelToken,
  }) => _request(
    () => dio.post<Object?>(
      'conversations',
      data: {
        'type': 'DIRECT',
        'subject': subject.trim(),
        'participantPersonIds': [recipientPersonId],
      },
      options: Options(extra: {'retryOnUnauthorized': false}),
      cancelToken: cancelToken,
    ),
    ConversationDetail.fromJson,
  );
  @override
  Future<MessagingPage<ConversationSummary>> conversations(
    MessagingQuery query, {
    CancelToken? cancelToken,
  }) => _request(
    () => dio.get<Object?>(
      'conversations',
      queryParameters: {'page': query.page, 'size': query.size},
      cancelToken: cancelToken,
    ),
    (json) => MessagingPage.fromJson(json, ConversationSummary.fromJson),
  );
  @override
  Future<ConversationDetail> conversation(
    String id, {
    CancelToken? cancelToken,
  }) => _request(
    () => dio.get<Object?>(_conversation(id), cancelToken: cancelToken),
    (json) {
      final value = ConversationDetail.fromJson(json);
      if (value.id != id) {
        throw const FormatException('Wrong conversation');
      }
      return value;
    },
  );
  @override
  Future<MessagingPage<Message>> messages(
    MessagingQuery query, {
    CancelToken? cancelToken,
  }) => _request(
    () => dio.get<Object?>(
      '${_conversation(query.conversationId!)}/messages',
      queryParameters: {'page': query.page, 'size': query.size},
      cancelToken: cancelToken,
    ),
    (json) {
      final value = MessagingPage.fromJson(json, Message.fromJson);
      if (value.content.any(
        (message) => message.conversationId != query.conversationId,
      )) {
        throw const FormatException('Wrong conversation');
      }
      return value;
    },
  );
  @override
  Future<Message> send(
    String conversationId,
    String content, {
    List<String> documentIds = const [],
    CancelToken? cancelToken,
  }) {
    if ((content.trim().isEmpty && documentIds.isEmpty) ||
        content.length > 10000 ||
        documentIds.length > 10) {
      throw const AppException(
        kind: AppErrorKind.validation,
        message: 'Message vide ou trop volumineux.',
      );
    }
    return _request(
      () => dio.post<Object?>(
        '${_conversation(conversationId)}/messages',
        data: {
          'type': documentIds.isEmpty ? 'TEXT' : 'DOCUMENT',
          'content': content.trim(),
          'documentIds': documentIds,
        },
        options: Options(extra: {'retryOnUnauthorized': false}),
        cancelToken: cancelToken,
      ),
      (json) {
        final result = Message.fromJson(json);
        if (result.conversationId != conversationId) {
          throw const FormatException('Wrong conversation');
        }
        return result;
      },
    );
  }

  @override
  Future<void> markRead(String messageId, {CancelToken? cancelToken}) async {
    await _request(
      () => dio.post<Object?>(
        'conversations/messages/${Uri.encodeComponent(messageId)}/read',
        options: Options(extra: {'retryOnUnauthorized': false}),
        cancelToken: cancelToken,
      ),
      (json) {
        if (json['messageId'] != messageId) {
          throw const FormatException('Wrong read receipt');
        }
        return json;
      },
    );
  }

  @override
  Future<MessagingAttachment> upload(
    String conversationId,
    String fileName,
    Uint8List bytes, {
    CancelToken? cancelToken,
  }) {
    if (bytes.isEmpty ||
        bytes.length > DioDocumentRepository.defaultMaxDownloadBytes) {
      throw const AppException(
        kind: AppErrorKind.validation,
        message: 'Fichier vide ou supérieur à 25 Mo.',
      );
    }
    return _request(
      () => dio.post<Object?>(
        '${_conversation(conversationId)}/attachments',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(
            bytes,
            filename: fileName,
            contentType: DioMediaType.parse(_uploadMime(fileName, bytes)),
          ),
        }),
        options: Options(extra: {'retryOnUnauthorized': false}),
        cancelToken: cancelToken,
      ),
      MessagingAttachment.fromJson,
    );
  }

  @override
  Future<MessagingAttachment> attachment(
    String conversationId,
    String documentId, {
    CancelToken? cancelToken,
  }) => _request(
    () => dio.get<Object?>(
      _attachment(conversationId, documentId),
      cancelToken: cancelToken,
    ),
    (json) {
      final result = MessagingAttachment.fromJson(json);
      if (result.id != documentId) {
        throw const FormatException('Wrong attachment');
      }
      return result;
    },
  );
  @override
  Future<DownloadedDocument> download(
    String conversationId,
    String documentId, {
    CancelToken? cancelToken,
  }) => DioDocumentRepository(
    dio,
    contentPath: (id) => '${_attachment(conversationId, id)}/content',
    metadataLoader: (id, token) async {
      final metadata = await attachment(conversationId, id, cancelToken: token);
      if (metadata.status != 'ACTIVE') {
        throw const FormatException('Inactive attachment');
      }
      return DocumentMetadata(
        id: metadata.id,
        documentNumber: metadata.id,
        patientId: '',
        fileName: metadata.fileName,
        mimeType: metadata.mimeType,
        sizeBytes: metadata.sizeBytes,
        uploadedAt: metadata.uploadedAt,
        status: metadata.status,
      );
    },
  ).download(documentId, cancelToken: cancelToken);
  Future<T> _request<T>(
    Future<Response<Object?>> Function() request,
    T Function(Map<String, dynamic>) decode,
  ) async {
    try {
      return decode(messagingMap((await request()).data));
    } on DioException catch (error) {
      if (error.error case final AppException mapped) {
        throw mapped;
      }
      throw AppException.fromDio(error);
    } on FormatException {
      throw _invalid;
    } on TypeError {
      throw _invalid;
    }
  }

  String _uploadMime(String name, Uint8List bytes) {
    final extension = name.split('.').last.toLowerCase();
    final mime = switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'txt' => 'text/plain',
      _ => throw const AppException(
        kind: AppErrorKind.validation,
        message: 'Format de fichier non pris en charge.',
      ),
    };
    if (mime == 'text/plain') {
      try {
        if (utf8.decode(bytes).contains('\u0000')) {
          throw const FormatException();
        }
      } on FormatException {
        throw const AppException(
          kind: AppErrorKind.validation,
          message: 'Fichier texte invalide.',
        );
      }
    }
    final signature = switch (mime) {
      'application/pdf' => [0x25, 0x50, 0x44, 0x46, 0x2d],
      'image/png' => [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
      'image/jpeg' => [0xff, 0xd8, 0xff],
      _ => const <int>[],
    };
    if (bytes.length < signature.length ||
        !List.generate(
          signature.length,
          (i) => bytes[i] == signature[i],
        ).every((match) => match)) {
      throw const AppException(
        kind: AppErrorKind.validation,
        message: 'Le contenu du fichier ne correspond pas à son format.',
      );
    }
    return mime;
  }

  static const _invalid = AppException(
    kind: AppErrorKind.unknown,
    message: 'La messagerie est temporairement indisponible.',
  );
}

final messagingRepositoryProvider = Provider<MessagingRepository>(
  (ref) => DioMessagingRepository(ref.watch(dioProvider)),
);
