import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/app/healthys_app.dart';
import 'package:healthysv2/app/router/app_router.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/patient/application/patient_dashboard_provider.dart';
import 'package:healthysv2/features/consultations/data/consultation_repository.dart';
import 'package:healthysv2/features/consultations/domain/consultation.dart';
import 'package:healthysv2/features/documents/application/document_export.dart';
import 'package:healthysv2/features/documents/data/document_repository.dart';
import 'package:healthysv2/features/documents/domain/document.dart';

const consultationId = '00000000-0000-0000-0000-000000000101';
const documentId = '00000000-0000-0000-0000-000000000102';
final started = DateTime.utc(2026, 10, 2, 14);
final consultation = ConsultationSummary(
  id: consultationId,
  consultationNumber: 'C-101',
  patientId: 'patient-not-for-display',
  professionalId: 'professional-not-for-display',
  professionalName: 'Dr Ada Lovelace',
  organizationId: 'org-not-for-display',
  organizationName: 'Clinic Québec',
  type: 'GENERAL',
  startedAt: started,
  completedAt: started.add(const Duration(minutes: 30)),
  status: 'COMPLETED',
);
ConsultationDetail detail({bool empty = false}) => ConsultationDetail(
  consultation: consultation,
  diagnoses: empty
      ? []
      : [
          PatientDiagnosis(
            id: 'diagnosis-not-for-display',
            diagnosisCatalogId: 'catalog-not-for-display',
            catalogCode: 'J45',
            catalogLabel: 'Asthma',
            diagnosisType: 'PRIMARY',
            description: 'Diagnosis shared with patient',
            status: 'CONFIRMED',
            diagnosedAt: started,
          ),
        ],
  notes: empty
      ? []
      : [
          PatientConsultationNote(
            id: 'note-not-for-display',
            noteType: 'SUMMARY',
            content: 'Shared consultation summary',
            createdAt: started,
            updatedAt: started,
          ),
        ],
);
final document = DocumentMetadata(
  id: documentId,
  documentNumber: 'DOC-102',
  patientId: 'patient-not-for-display',
  categoryName: 'Clinical document',
  fileName: 'visit-summary.txt',
  mimeType: 'text/plain',
  sizeBytes: 25,
  uploadedAt: started,
  status: 'ACTIVE',
);

class FakeConsultations implements ConsultationRepository {
  Object? error;
  bool empty = false;
  bool detailEmpty = false;
  final queries = <ConsultationListQuery>[];
  @override
  Future<ConsultationPage> list(
    ConsultationListQuery query, {
    CancelToken? cancelToken,
  }) async {
    queries.add(query);
    if (error != null) throw error!;
    return ConsultationPage(
      content: empty ? [] : [consultation],
      number: query.page,
      size: 20,
      totalElements: empty ? 0 : 21,
      totalPages: empty ? 0 : 2,
      first: query.page == 0,
      last: query.page == 1 || empty,
    );
  }

  @override
  Future<ConsultationDetail> detail(
    String id, {
    CancelToken? cancelToken,
  }) async {
    if (error != null) throw error!;
    return FakeConsultations.record(detailEmpty);
  }

  static ConsultationDetail record(bool empty) => detailRecord(empty: empty);
}

ConsultationDetail detailRecord({bool empty = false}) => detail(empty: empty);

class FakeDocuments implements DocumentRepository {
  Object? error;
  bool empty = false;
  int downloads = 0;
  Completer<DownloadedDocument>? pending;
  final queries = <DocumentListQuery>[];
  @override
  Future<DocumentPage> list(
    DocumentListQuery query, {
    CancelToken? cancelToken,
  }) async {
    queries.add(query);
    if (error != null) throw error!;
    return DocumentPage(
      content: empty ? [] : [document],
      number: query.page,
      size: 20,
      totalElements: empty ? 0 : 1,
      totalPages: empty ? 0 : 1,
      first: true,
      last: true,
    );
  }

  @override
  Future<DocumentMetadata> detail(String id, {CancelToken? cancelToken}) async {
    if (error != null) throw error!;
    return document;
  }

  @override
  Future<DownloadedDocument> download(
    String id, {
    CancelToken? cancelToken,
  }) async {
    downloads++;
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return DownloadedDocument(
      metadata: document,
      bytes: Uint8List.fromList(utf8.encode('Patient-visible document')),
    );
  }
}

class FakeExporter implements DocumentExporter {
  int saves = 0;
  bool result = true;
  Object? error;
  @override
  Future<bool> save(DownloadedDocument downloaded) async {
    saves++;
    if (error != null) throw error!;
    return result;
  }
}

class ClinicalSession extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'person1'}),
  );
  void markExpired() =>
      state = const SessionState(status: SessionStatus.expired);
}

Future<ProviderContainer> pumpClinical(
  WidgetTester tester,
  String path, {
  FakeConsultations? consultations,
  FakeDocuments? documents,
  FakeExporter? exporter,
  ClinicalSession? session,
  bool french = false,
}) async {
  tester.binding.platformDispatcher.localesTestValue = [
    Locale(french ? 'fr' : 'en'),
  ];
  addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
  final container = ProviderContainer(
    overrides: [
      sessionControllerProvider.overrideWith(
        () => session ?? ClinicalSession(),
      ),
      patientDashboardProvider.overrideWith((ref) async => null),
      consultationRepositoryProvider.overrideWithValue(
        consultations ?? FakeConsultations(),
      ),
      documentRepositoryProvider.overrideWithValue(
        documents ?? FakeDocuments(),
      ),
      documentExporterProvider.overrideWithValue(exporter ?? FakeExporter()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const HealthysApp()),
  );
  container.read(appRouterProvider).go(path);
  await tester.pumpAndSettle();
  return container;
}

Future<void> revealText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'safe local destinations cover consultations filtered documents and preview',
    () {
      for (final path in [
        '/consultations',
        '/consultations/$consultationId',
        '/consultations/$consultationId/documents',
        '/documents',
        '/documents/$documentId/view',
      ]) {
        expect(safeReturnPath(path), path);
      }
      expect(safeReturnPath('/documents/not-a-uuid/view'), '/');
      expect(
        safeReturnPath('https://evil.example/documents/$documentId/view'),
        '/',
      );
    },
  );
  testWidgets(
    'consultation history paginates named records and opens allowed summary',
    (tester) async {
      final repository = FakeConsultations();
      await pumpClinical(tester, '/consultations', consultations: repository);
      expect(find.textContaining('Dr Ada Lovelace'), findsOneWidget);
      expect(find.textContaining('patient-not-for-display'), findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.page, 1);
      expect(find.text('Page 2 / 2'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('C-101'), findsOneWidget);
      await revealText(tester, 'Asthma');
      expect(find.text('J45'), findsOneWidget);
      expect(find.text('catalog-not-for-display'), findsNothing);
      await revealText(tester, 'Shared consultation summary');
      expect(find.text('Shared consultation summary'), findsOneWidget);
    },
  );
  testWidgets(
    'French consultation detail renders actual labels and linked documents filter',
    (tester) async {
      final documents = FakeDocuments();
      await pumpClinical(
        tester,
        '/consultations/$consultationId',
        documents: documents,
        french: true,
      );
      expect(find.text('Résumé de la consultation'), findsOneWidget);
      await revealText(tester, 'Diagnostics');
      await revealText(tester, 'Notes partagées');
      await revealText(tester, 'Documents de cette consultation');
      await tester.tap(find.text('Documents de cette consultation'));
      await tester.pumpAndSettle();
      expect(documents.queries.last.consultationId, consultationId);
      expect(find.text('Documents de la consultation'), findsOneWidget);
      expect(find.text('visit-summary.txt'), findsOneWidget);
    },
  );
  testWidgets('empty history and empty shared clinical details are explicit', (
    tester,
  ) async {
    await pumpClinical(
      tester,
      '/consultations',
      consultations: FakeConsultations()..empty = true,
    );
    expect(find.text('No recorded consultations.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pumpClinical(
      tester,
      '/consultations/$consultationId',
      consultations: FakeConsultations()..detailEmpty = true,
    );
    expect(find.text('No shared diagnoses.'), findsOneWidget);
    expect(find.text('No shared notes.'), findsOneWidget);
  });
  testWidgets('consultation errors hide diagnostics and retry reads safely', (
    tester,
  ) async {
    final repository = FakeConsultations()
      ..error = const AppException(
        kind: AppErrorKind.forbidden,
        statusCode: 403,
        message: 'private physician text',
      );
    await pumpClinical(
      tester,
      '/consultations/$consultationId',
      consultations: repository,
    );
    expect(
      find.text('You do not have permission to perform this action.'),
      findsOneWidget,
    );
    expect(find.text('private physician text'), findsNothing);
    repository.error = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('C-101'), findsOneWidget);
  });
  testWidgets(
    'documents list shows safe metadata and explicit export saves once',
    (tester) async {
      final repository = FakeDocuments();
      final exporter = FakeExporter();
      await pumpClinical(
        tester,
        '/documents',
        documents: repository,
        exporter: exporter,
      );
      expect(find.text('visit-summary.txt'), findsOneWidget);
      expect(find.text('Clinical document'), findsOneWidget);
      expect(repository.downloads, 0);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(repository.downloads, 1);
      expect(exporter.saves, 1);
      expect(find.text('Document saved.'), findsOneWidget);
    },
  );
  testWidgets('cancelled native export produces no false success', (
    tester,
  ) async {
    final exporter = FakeExporter()..result = false;
    await pumpClinical(tester, '/documents', exporter: exporter);
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    expect(exporter.saves, 1);
    expect(find.text('Document saved.'), findsNothing);
  });
  testWidgets(
    'view navigates protected preview and fetches bytes only on deliberate action',
    (tester) async {
      final repository = FakeDocuments();
      await pumpClinical(tester, '/documents', documents: repository);
      expect(repository.downloads, 0);
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(repository.downloads, 1);
      expect(find.text('Patient-visible document'), findsOneWidget);
    },
  );
  testWidgets(
    'empty documents and unavailable consultation states are explicit',
    (tester) async {
      await pumpClinical(
        tester,
        '/documents',
        documents: FakeDocuments()..empty = true,
        french: true,
      );
      expect(find.text('Aucun document disponible.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pumpClinical(
        tester,
        '/consultations/$consultationId/documents',
        documents: FakeDocuments()..empty = true,
      );
      expect(
        find.text('No documents linked to this consultation.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'download failure shows controlled copy and does not retry automatically',
    (tester) async {
      final repository = FakeDocuments();
      await pumpClinical(tester, '/documents', documents: repository);
      repository.error = const AppException(
        kind: AppErrorKind.server,
        statusCode: 500,
        message: 'secret object-storage key',
      );
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(
        find.text('The service is temporarily unavailable.'),
        findsOneWidget,
      );
      expect(find.text('secret object-storage key'), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(repository.downloads, 1);
    },
  );
  testWidgets(
    'expiry during download prevents export and removes document data',
    (tester) async {
      final repository = FakeDocuments()
        ..pending = Completer<DownloadedDocument>();
      final exporter = FakeExporter();
      final session = ClinicalSession();
      await pumpClinical(
        tester,
        '/documents',
        documents: repository,
        exporter: exporter,
        session: session,
      );
      await tester.tap(find.text('Download'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Download'))
            .onPressed,
        isNull,
      );
      session.markExpired();
      await tester.pumpAndSettle();
      repository.pending!.complete(
        DownloadedDocument(
          metadata: document,
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      );
      await tester.pumpAndSettle();
      expect(exporter.saves, 0);
      expect(find.text('visit-summary.txt'), findsNothing);
      expect(
        find.text('Your session has expired. Sign in again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
