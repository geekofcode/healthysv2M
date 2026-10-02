import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/core/network/api_client.dart';
import 'package:healthysv2/core/storage/token_store.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/documents/application/document_providers.dart';
import 'package:healthysv2/features/documents/data/document_repository.dart';
import 'package:healthysv2/features/documents/domain/document.dart';
import 'document_fixtures.dart';

class Tokens implements TokenStore {
  @override
  Future<String?> readAccessToken() async => 'access-token';
  @override
  Future<void> writeAccessToken(String token) async {}
  @override
  Future<void> clear() async {}
}

class Adapter implements HttpClientAdapter {
  Map<String, dynamic> metadata = documentJson();
  bool listing = false;
  int contentStatus = 200;
  String contentType = 'application/pdf';
  String? contentLength;
  List<List<int>> chunks = [utf8.encode('%PDF-1.7')];
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (!options.path.endsWith('/content')) {
      return ResponseBody.fromString(
        jsonEncode(listing ? documentPageJson() : metadata),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody(
      Stream.fromIterable(chunks.map(Uint8List.fromList)),
      contentStatus,
      headers: {
        Headers.contentTypeHeader: [contentType],
        if (contentLength != null)
          Headers.contentLengthHeader: [contentLength!],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class Session extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'person-1'}),
  );
  void signOut() => state = const SessionState(status: SessionStatus.signedOut);
  void switchUser() => state = const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'person-2'}),
  );
}

class PendingRepository implements DocumentRepository {
  final pending = <Completer<DownloadedDocument>>[];
  final tokens = <CancelToken?>[];
  int downloads = 0;
  @override
  Future<DownloadedDocument> download(String id, {CancelToken? cancelToken}) {
    downloads++;
    tokens.add(cancelToken);
    final request = Completer<DownloadedDocument>();
    pending.add(request);
    return request.future;
  }

  @override
  Future<DocumentMetadata> detail(
    String id, {
    CancelToken? cancelToken,
  }) async => DocumentMetadata.fromJson(documentJson(id: id));
  @override
  Future<DocumentPage> list(
    DocumentListQuery query, {
    CancelToken? cancelToken,
  }) async => DocumentPage.fromJson(documentPageJson());
}

void main() {
  late Dio dio;
  late Adapter adapter;
  late DioDocumentRepository repository;
  setUp(() {
    dio = createApiClient(
      baseUrl: Uri.parse('https://api.test/api/v1'),
      tokenStore: Tokens(),
    );
    adapter = Adapter();
    dio.httpClientAdapter = adapter;
    repository = DioDocumentRepository(dio);
  });
  tearDown(() => dio.close());
  test(
    'metadata is paginated and optionally linked to an owned consultation without fetching content',
    () async {
      adapter.listing = true;
      final page = await repository.list(
        const DocumentListQuery(
          consultationId: 'consultation-1',
          page: 2,
          size: 10,
        ),
      );
      expect(page.content.single.fileName, 'report.pdf');
      expect(adapter.requests.single.queryParameters, {
        'consultationId': 'consultation-1',
        'page': 2,
        'size': 10,
      });
      expect(adapter.requests.single.uri.path, '/api/v1/patients/me/documents');
      expect(
        adapter.requests.any((request) => request.path.endsWith('/content')),
        false,
      );
    },
  );
  test(
    'download fetches authorized metadata and bytes using the bearer on both requests',
    () async {
      adapter.contentLength = '8';
      final downloaded = await repository.download('document-1');
      expect(downloaded.metadata.id, 'document-1');
      expect(utf8.decode(downloaded.bytes), '%PDF-1.7');
      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests.map((request) => request.headers['Authorization']),
        everyElement('Bearer access-token'),
      );
      expect(
        adapter.requests.last.uri.path,
        '/api/v1/patients/me/documents/document-1/content',
      );
      expect(adapter.requests.last.followRedirects, false);
      expect(adapter.requests.last.responseType, ResponseType.stream);
    },
  );
  test(
    'large unsupported inactive and mismatched documents never start a binary request',
    () async {
      for (final metadata in [
        documentJson(
          sizeBytes: DioDocumentRepository.defaultMaxDownloadBytes + 1,
        ),
        documentJson(mimeType: 'text/html'),
        documentJson(status: 'ARCHIVED'),
        documentJson(id: 'foreign'),
      ]) {
        adapter.requests.clear();
        adapter.metadata = metadata;
        await expectLater(
          repository.download('document-1'),
          throwsA(isA<AppException>()),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );
  test(
    'wrong MIME and invalid signatures are rejected before handing content to a viewer',
    () async {
      adapter.contentType = 'text/html';
      await expectLater(
        repository.download('document-1'),
        throwsA(isA<AppException>()),
      );
      adapter.contentType = 'application/pdf';
      adapter.chunks = [utf8.encode('<html>!!')];
      await expectLater(
        repository.download('document-1'),
        throwsA(isA<AppException>()),
      );
    },
  );
  test(
    'stream is bounded by metadata even when HTTP length is absent or misleading',
    () async {
      final token = CancelToken();
      adapter.chunks = [utf8.encode('%PDF-1.7'), List.filled(100, 0)];
      await expectLater(
        repository.download('document-1', cancelToken: token),
        throwsA(isA<AppException>()),
      );
      expect(token.isCancelled, true);
      adapter.chunks = [utf8.encode('%PDF')];
      await expectLater(
        repository.download('document-1'),
        throwsA(isA<AppException>()),
      );
      adapter.chunks = [utf8.encode('%PDF-1.7')];
      adapter.contentLength = '900';
      await expectLater(
        repository.download('document-1'),
        throwsA(isA<AppException>()),
      );
    },
  );
  test(
    'PNG JPEG and UTF8 text use matching signatures and strict UTF8',
    () async {
      for (final sample in <(String, List<int>)>[
        ('image/png', [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        ('image/jpeg', [0xff, 0xd8, 0xff, 0xd9]),
        ('text/plain', utf8.encode('Résumé patient')),
      ]) {
        adapter.metadata = documentJson(
          mimeType: sample.$1,
          sizeBytes: sample.$2.length,
        );
        adapter.contentType = sample.$1;
        adapter.chunks = [sample.$2];
        expect((await repository.download('document-1')).bytes, sample.$2);
      }
      adapter.metadata = documentJson(mimeType: 'text/plain', sizeBytes: 1);
      adapter.chunks = [
        [0xff],
      ];
      await expectLater(
        repository.download('document-1'),
        throwsA(isA<AppException>()),
      );
    },
  );
  test(
    '401 403 and redirects do not return unauthenticated binary content',
    () async {
      for (final status in [401, 403, 302]) {
        adapter.contentStatus = status;
        await expectLater(
          repository.download('document-1'),
          throwsA(isA<AppException>()),
        );
      }
    },
  );
  for (final logout in [true, false]) {
    test(
      '${logout ? 'logout' : 'account switch'} cancels download and discards late binary data',
      () async {
        final session = Session();
        final pending = PendingRepository();
        final container = ProviderContainer(
          overrides: [
            sessionControllerProvider.overrideWith(() => session),
            documentRepositoryProvider.overrideWithValue(pending),
          ],
        );
        final subscription = container.listen(
          downloadedDocumentProvider('document-1'),
          (_, _) {},
        );
        await Future<void>.delayed(Duration.zero);
        if (logout) {
          session.signOut();
        } else {
          session.switchUser();
        }
        // Read forces rebuilding the session-bound provider after account changes.
        container.read(downloadedDocumentProvider('document-1'));
        expect(pending.tokens.first?.isCancelled, true);
        if (logout) {
          expect(
            await container.read(
              downloadedDocumentProvider('document-1').future,
            ),
            isNull,
          );
        }
        pending.pending.first.complete(
          DownloadedDocument(
            metadata: DocumentMetadata.fromJson(documentJson()),
            bytes: Uint8List.fromList(utf8.encode('%PDF-1.7')),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        if (logout) {
          expect(
            container.read(downloadedDocumentProvider('document-1')).value,
            isNull,
          );
        } else {
          expect(
            container.read(downloadedDocumentProvider('document-1')).isLoading,
            true,
          );
          expect(pending.downloads, 2);
          pending.pending.last.complete(
            DownloadedDocument(
              metadata: DocumentMetadata.fromJson(documentJson()),
              bytes: Uint8List.fromList(utf8.encode('%PDF-2.0')),
            ),
          );
          final fresh = await container.read(
            downloadedDocumentProvider('document-1').future,
          );
          expect(utf8.decode(fresh!.bytes), '%PDF-2.0');
        }
        subscription.close();
        container.dispose();
      },
    );
  }
}
