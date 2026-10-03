import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/consultations/application/consultation_providers.dart';
import 'package:healthysv2/features/consultations/data/consultation_repository.dart';
import 'package:healthysv2/features/consultations/domain/consultation.dart';
import 'consultation_fixtures.dart';

class Adapter implements HttpClientAdapter {
  Object? body = consultationPageJson();
  int status = 200;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
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
}

class PendingRepository implements ConsultationRepository {
  final pending = Completer<ConsultationDetail>();
  CancelToken? token;
  int calls = 0;
  @override
  Future<ConsultationDetail> detail(String id, {CancelToken? cancelToken}) {
    calls++;
    token = cancelToken;
    return pending.future;
  }

  @override
  Future<ConsultationPage> list(
    ConsultationListQuery query, {
    CancelToken? cancelToken,
  }) async {
    calls++;
    return ConsultationPage.fromJson(consultationPageJson());
  }
}

void main() {
  late Dio dio;
  late Adapter adapter;
  late DioConsultationRepository repository;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1/'));
    adapter = Adapter();
    dio.httpClientAdapter = adapter;
    repository = DioConsultationRepository(dio);
  });
  tearDown(() => dio.close());
  test('self-history pagination never requests another patient', () async {
    final page = await repository.list(
      const ConsultationListQuery(page: 2, size: 10),
    );
    expect(page.content.single.professionalName, 'Jane Smith');
    expect(page.totalElements, 1);
    expect(
      adapter.requests.single.uri.path,
      '/api/v1/patients/me/consultations',
    );
    expect(adapter.requests.single.queryParameters, {'page': 2, 'size': 10});
  });
  test(
    'detail maps only patient-safe projection without professional notes or treatment plans',
    () async {
      adapter.body = {
        ...consultationDetailJson(),
        'internalNotes': [
          {'content': 'private'},
        ],
        'treatments': [
          {'description': 'private plan'},
        ],
        'followUps': [
          {'instructions': 'private'},
        ],
      };
      final detail = await repository.detail('consultation-1');
      expect(detail.consultation.status, 'COMPLETED');
      expect(detail.diagnoses.single.description, 'Patient-visible diagnosis');
      expect(detail.notes.single.content, 'Patient-visible summary');
      expect(detail.notes.single.updatedAt.isUtc, true);
      expect(
        adapter.requests.single.path,
        'patients/me/consultations/consultation-1',
      );
    },
  );
  test(
    'noncompleted and malformed payloads are never retained as clinical models',
    () async {
      adapter.body = {
        ...consultationDetailJson(),
        'consultation': consultationJson(status: 'IN_PROGRESS'),
      };
      await expectLater(
        repository.detail('consultation-1'),
        throwsA(isA<AppException>()),
      );
      adapter.body = '<html>gateway diagnostics</html>';
      await expectLater(
        repository.detail('consultation-1'),
        throwsA(isA<AppException>()),
      );
    },
  );
  test('ownership denial remains typed and safe', () async {
    adapter.status = 403;
    adapter.body = {'message': 'Forbidden', 'code': 'ACCESS_DENIED'};
    await expectLater(
      repository.detail('foreign-consultation'),
      throwsA(
        isA<AppException>().having(
          (error) => error.kind,
          'kind',
          AppErrorKind.forbidden,
        ),
      ),
    );
  });
  test('logout cancels detail and discards late visible content', () async {
    final session = Session();
    final pending = PendingRepository();
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(() => session),
        consultationRepositoryProvider.overrideWithValue(pending),
      ],
    );
    final subscription = container.listen(
      consultationDetailProvider('consultation-1'),
      (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);
    session.signOut();
    expect(
      await container.read(consultationDetailProvider('consultation-1').future),
      isNull,
    );
    expect(pending.token?.isCancelled, true);
    pending.pending.complete(
      ConsultationDetail.fromJson(consultationDetailJson()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(consultationDetailProvider('consultation-1')).value,
      isNull,
    );
    expect(
      await container.read(
        consultationsProvider(const ConsultationListQuery()).future,
      ),
      isNull,
    );
    expect(pending.calls, 1);
    subscription.close();
    container.dispose();
  });
}
