import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/document.dart';

abstract interface class DocumentRepository {
  Future<DocumentPage> list(
    DocumentListQuery query, {
    CancelToken? cancelToken,
  });
  Future<DocumentMetadata> detail(String id, {CancelToken? cancelToken});
  Future<DownloadedDocument> download(String id, {CancelToken? cancelToken});
}

class DioDocumentRepository implements DocumentRepository {
  DioDocumentRepository(
    this.dio, {
    this.maxDownloadBytes = defaultMaxDownloadBytes,
    this.contentPath,
    this.metadataLoader,
  });
  final Dio dio;
  final int maxDownloadBytes;
  final String Function(String id)? contentPath;
  final Future<DocumentMetadata> Function(String id, CancelToken token)?
  metadataLoader;
  static const defaultMaxDownloadBytes = 25 * 1024 * 1024;
  static const supportedMimeTypes = {
    'application/pdf',
    'image/png',
    'image/jpeg',
    'text/plain',
  };
  static const _path = 'patients/me/documents';

  @override
  Future<DocumentPage> list(
    DocumentListQuery query, {
    CancelToken? cancelToken,
  }) => _request(
    () => dio.get<Object?>(
      _path,
      queryParameters: {
        'page': query.page,
        'size': query.size,
        if (query.consultationId != null)
          'consultationId': query.consultationId,
      },
      cancelToken: cancelToken,
    ),
    DocumentPage.fromJson,
  );
  @override
  Future<DocumentMetadata> detail(String id, {CancelToken? cancelToken}) =>
      _request(
        () => dio.get<Object?>(
          '$_path/${Uri.encodeComponent(id)}',
          cancelToken: cancelToken,
        ),
        (json) {
          final metadata = DocumentMetadata.fromJson(json);
          if (metadata.id != id) {
            throw const FormatException('Mismatched document');
          }
          return metadata;
        },
      );

  @override
  Future<DownloadedDocument> download(
    String id, {
    CancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? CancelToken();
    try {
      final metadata = metadataLoader == null
          ? await detail(id, cancelToken: token)
          : await metadataLoader!(id, token);
      _checkMetadata(metadata);
      _ensureNotCancelled(token);
      final response = await dio.get<ResponseBody>(
        contentPath?.call(id) ?? '$_path/${Uri.encodeComponent(id)}/content',
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          headers: {'Accept': metadata.mimeType},
        ),
        cancelToken: token,
      );
      final body = response.data;
      if (body == null) throw const FormatException('Missing document body');
      _checkHeaders(response, metadata);
      final bytes = await _readBounded(body.stream, metadata, token);
      _checkSignature(bytes, _mime(metadata.mimeType));
      _ensureNotCancelled(token);
      return DownloadedDocument(metadata: metadata, bytes: bytes);
    } on DioException catch (error) {
      if (error.error case final AppException mapped) throw mapped;
      throw AppException.fromDio(error);
    } on FormatException {
      token.cancel('Invalid document content');
      throw _invalidResponse;
    } on TypeError {
      token.cancel('Invalid document content');
      throw _invalidResponse;
    }
  }

  void _ensureNotCancelled(CancelToken token) {
    if (token.cancelError case final DioException error) {
      throw error;
    }
  }

  void _checkMetadata(DocumentMetadata metadata) {
    if (metadata.sizeBytes <= 0 ||
        metadata.sizeBytes > maxDownloadBytes ||
        !supportedMimeTypes.contains(_mime(metadata.mimeType))) {
      throw const FormatException('Unsupported or oversized document');
    }
  }

  String _mime(String value) => value.split(';').first.trim().toLowerCase();
  void _checkHeaders(
    Response<ResponseBody> response,
    DocumentMetadata metadata,
  ) {
    if (response.statusCode != 200 ||
        _mime(response.headers.value(Headers.contentTypeHeader) ?? '') !=
            _mime(metadata.mimeType)) {
      throw const FormatException('Invalid document content type');
    }
    final length = response.headers.value(Headers.contentLengthHeader);
    if (length != null && int.tryParse(length) != metadata.sizeBytes) {
      throw const FormatException('Invalid document content length');
    }
  }

  Future<Uint8List> _readBounded(
    Stream<Uint8List> stream,
    DocumentMetadata metadata,
    CancelToken token,
  ) async {
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      _ensureNotCancelled(token);
      if (buffer.length + chunk.length > maxDownloadBytes ||
          buffer.length + chunk.length > metadata.sizeBytes) {
        throw const FormatException('Document exceeded advertised size');
      }
      buffer.add(chunk);
    }
    if (buffer.length != metadata.sizeBytes) {
      throw const FormatException('Truncated document');
    }
    return buffer.takeBytes();
  }

  bool _startsWith(Uint8List bytes, List<int> signature) =>
      bytes.length >= signature.length &&
      List.generate(
        signature.length,
        (index) => bytes[index] == signature[index],
      ).every((equal) => equal);
  void _checkSignature(Uint8List bytes, String mime) {
    final valid = switch (mime) {
      'application/pdf' => _startsWith(bytes, const [
        0x25,
        0x50,
        0x44,
        0x46,
        0x2d,
      ]),
      'image/png' => _startsWith(bytes, const [
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ]),
      'image/jpeg' => _startsWith(bytes, const [0xff, 0xd8, 0xff]),
      'text/plain' => !utf8.decode(bytes).contains('\u0000'),
      _ => false,
    };
    if (!valid) throw const FormatException('Document signature mismatch');
  }

  Future<T> _request<T>(
    Future<Response<Object?>> Function() send,
    T Function(Map<String, dynamic>) decode,
  ) async {
    try {
      final response = await send();
      if (response.data is! Map<String, dynamic>) {
        throw const FormatException('Invalid document response');
      }
      return decode(response.data! as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.error case final AppException mapped) throw mapped;
      throw AppException.fromDio(error);
    } on FormatException {
      throw _invalidResponse;
    } on TypeError {
      throw _invalidResponse;
    }
  }

  static const _invalidResponse = AppException(
    kind: AppErrorKind.unknown,
    message:
        'Ce document est temporairement indisponible ou ne peut pas être ouvert.',
  );
}

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => DioDocumentRepository(ref.watch(dioProvider)),
);
