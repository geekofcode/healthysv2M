import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/prescriptions/application/prescription_providers.dart';
import 'package:healthysv2/features/prescriptions/data/prescription_repository.dart';
import 'package:healthysv2/features/prescriptions/domain/prescription.dart';
import 'prescription_fixtures.dart';

class Adapter implements HttpClientAdapter {
  Object? body = pageJson();
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
  void changeAccount() => state = const SessionState(
    status: SessionStatus.authenticated,
    profile: MobileProfile({'id': 'person-2'}),
  );
  void signOut() => state = const SessionState(status: SessionStatus.signedOut);
}

class PendingRepository implements PrescriptionRepository {
  final pending = Completer<PrescriptionDetail>();
  CancelToken? token;
  int calls = 0;
  @override
  Future<PrescriptionDetail> detail(String id, {CancelToken? cancelToken}) {
    calls++;
    token = cancelToken;
    return pending.future;
  }

  @override
  Future<PrescriptionPage> list(
    PrescriptionListQuery query, {
    CancelToken? cancelToken,
  }) async {
    calls++;
    return PrescriptionPage.fromJson(pageJson());
  }
}

void main() {
  late Dio dio;
  late Adapter adapter;
  late DioPrescriptionRepository repository;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1/'));
    adapter = Adapter();
    dio.httpClientAdapter = adapter;
    repository = DioPrescriptionRepository(dio);
  });
  tearDown(() => dio.close());
  test('self-history pagination never requests another patient', () async {
    final page = await repository.list(
      const PrescriptionListQuery(page: 2, size: 10),
    );
    expect(page.content.single.prescriberName, 'Médecin');
    expect(page.totalElements, 1);
    expect(
      adapter.requests.single.uri.path,
      '/api/v1/patients/me/prescriptions',
    );
    expect(adapter.requests.single.queryParameters, {'page': 2, 'size': 10});
  });
  test(
    'detail maps only patient-safe projection without professional notes or treatment plans',
    () async {
      adapter.body = {
        ...detailJson(),
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
      final detail = await repository.detail('rx-1');
      expect(detail.prescription.status, 'PARTIALLY_DISPENSED');
      expect(detail.prescription.expired, false);
      expect(detail.items.single.quantityRemaining, '20');
      expect(detail.items.single.dosage, '1 comprimé');
      expect(detail.dispensations.single.items.single.quantityDispensed, '10');
      expect(adapter.requests.single.path, 'patients/me/prescriptions/rx-1');
    },
  );
  test(
    'invalid and malformed payloads are never retained as clinical models',
    () async {
      adapter.body = {
        ...detailJson(),
        'prescription': {...summaryJson(), 'expired': 'false'},
      };
      await expectLater(
        repository.detail('rx-1'),
        throwsA(isA<AppException>()),
      );
      adapter.body = '<html>gateway diagnostics</html>';
      await expectLater(
        repository.detail('rx-1'),
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
        prescriptionRepositoryProvider.overrideWithValue(pending),
      ],
    );
    final subscription = container.listen(
      prescriptionDetailProvider('rx-1'),
      (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);
    session.signOut();
    expect(
      await container.read(prescriptionDetailProvider('rx-1').future),
      isNull,
    );
    expect(pending.token?.isCancelled, true);
    pending.pending.complete(PrescriptionDetail.fromJson(detailJson()));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(prescriptionDetailProvider('rx-1')).value, isNull);
    expect(
      await container.read(
        prescriptionsProvider(const PrescriptionListQuery()).future,
      ),
      isNull,
    );
    expect(pending.calls, 1);
    subscription.close();
    container.dispose();
  });
  test('mismatched detail identity is rejected', () async {
    adapter.body = detailJson();
    await expectLater(
      repository.detail('other-id'),
      throwsA(isA<AppException>()),
    );
  });
  test('not found remains a controlled error', () async {
    adapter.status = 404;
    adapter.body = {'message': 'Not found', 'code': 'NOT_FOUND'};
    await expectLater(
      repository.detail('rx-1'),
      throwsA(
        isA<AppException>().having((e) => e.statusCode, 'statusCode', 404),
      ),
    );
  });
  test('account change cancels old request before new response', () async {
    final session = Session();
    final repository = PendingRepository();
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(() => session),
        prescriptionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    final subscription = container.listen(
      prescriptionDetailProvider('rx-1'),
      (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);
    final oldToken = repository.token!;
    session.changeAccount();
    await Future<void>.delayed(Duration.zero);
    expect(oldToken.isCancelled, true);
    expect(repository.calls, 2);
    subscription.close();
    container.dispose();
    repository.pending.complete(PrescriptionDetail.fromJson(detailJson()));
    await Future<void>.delayed(Duration.zero);
  });
  test(
    'expired prescription status and fractional quantities remain server values',
    () async {
      final json = detailJson();
      json['prescription'] = {
        ...summaryJson(),
        'expired': true,
        'status': 'ACTIVE',
      };
      final items = json['items'] as List;
      items.single['quantity'] = 1.25;
      items.single['quantityDispensed'] = 0.5;
      items.single['quantityRemaining'] = 0.75;
      adapter.body = json;
      final result = await repository.detail('rx-1');
      expect(result.prescription.status, 'ACTIVE');
      expect(result.prescription.expired, true);
      expect(result.items.single.quantityRemaining, '0.75');
      expect(result.items.single.quantityDispensed, '0.5');
    },
  );
  test('missing optional organization remains readable', () {
    final summary = PrescriptionSummary.fromJson({
      ...summaryJson(),
      'organizationId': null,
    });
    expect(summary.organizationId, isNull);
  });
  test('draft prescription is rejected', () {
    expect(
      () => PrescriptionSummary.fromJson({...summaryJson(), 'status': 'DRAFT'}),
      throwsFormatException,
    );
  });
}
