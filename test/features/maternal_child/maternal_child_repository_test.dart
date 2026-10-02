import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/errors/app_exception.dart';
import 'package:healthysv2/features/auth/application/session_controller.dart';
import 'package:healthysv2/features/auth/domain/session.dart';
import 'package:healthysv2/features/maternal_child/application/maternal_child_providers.dart';
import 'package:healthysv2/features/maternal_child/data/maternal_child_repository.dart';
import 'package:healthysv2/features/maternal_child/domain/maternal_child.dart';
import 'maternal_child_fixtures.dart';

class Adapter implements HttpClientAdapter {
  Object? body = notebookPageJson([pregnancyJson()]);
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

class PendingRepository implements MaternalChildRepository {
  final pending = <Completer<ChildDetail>>[];
  final tokens = <CancelToken?>[];
  int calls = 0;
  @override
  Future<ChildDetail> child(String id, {CancelToken? cancelToken}) {
    calls++;
    tokens.add(cancelToken);
    final completer = Completer<ChildDetail>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<MaternalPage<ChildSummary>> children(
    MaternalChildListQuery query, {
    CancelToken? cancelToken,
  }) async {
    calls++;
    return MaternalPage.fromJson(
      notebookPageJson([childJson()]),
      ChildSummary.fromJson,
    );
  }

  @override
  Future<MaternalPage<PregnancySummary>> pregnancies(
    MaternalChildListQuery query, {
    CancelToken? cancelToken,
  }) async {
    calls++;
    return MaternalPage.fromJson(
      notebookPageJson([pregnancyJson()]),
      PregnancySummary.fromJson,
    );
  }

  @override
  Future<PregnancyDetail> pregnancy(
    String id, {
    CancelToken? cancelToken,
  }) async {
    calls++;
    return PregnancyDetail.fromJson(pregnancyDetailJson());
  }
}

void main() {
  late Dio dio;
  late Adapter adapter;
  late DioMaternalChildRepository repository;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1/'));
    adapter = Adapter();
    dio.httpClientAdapter = adapter;
    repository = DioMaternalChildRepository(dio);
  });
  tearDown(() => dio.close());
  test(
    'self pregnancies and children use pagination without selecting another mother',
    () async {
      final page = await repository.pregnancies(
        const MaternalChildListQuery(page: 2, size: 10),
      );
      expect(page.content.single.pregnancyNumber, 'G-001');
      expect(
        adapter.requests.last.uri.path,
        '/api/v1/patients/me/maternal-child/pregnancies',
      );
      expect(adapter.requests.last.queryParameters, {'page': 2, 'size': 10});
      adapter.body = notebookPageJson([childJson()]);
      final children = await repository.children(
        const MaternalChildListQuery(),
      );
      expect(children.content.single.childPatientId, 'child-1');
      expect(adapter.requests.last.path, 'patients/me/maternal-child/children');
    },
  );
  test(
    'prenatal and newborn measurements preserve null and calendar dates',
    () async {
      adapter.body = pregnancyDetailJson();
      final detail = await repository.pregnancy('pregnancy-1');
      expect(detail.pregnancy.expectedDeliveryDate, '2027-03-10');
      expect(detail.lastMenstrualPeriod, '2026-06-03');
      expect(detail.estimatedConceptionDate, isNull);
      expect(detail.prenatalVisits.single.weightKg, '62.5');
      expect(detail.prenatalVisits.single.fetalHeartRate, isNull);
      expect(
        detail.prenatalVisits.single.visitDate,
        DateTime.utc(2026, 8, 1, 14),
      );
      expect(detail.delivery!.newborns.single.birthWeightKg, '3.25');
    },
  );
  test('child detail uses patient id rather than notebook record id', () async {
    adapter.body = childDetailJson();
    final detail = await repository.child('child-1');
    expect(detail.child.id, 'record-1');
    expect(
      adapter.requests.single.path,
      'patients/me/maternal-child/children/child-1',
    );
    expect(detail.vaccinations.single.vaccineName, isNull);
    expect(detail.vaccinations.single.nextDueDate, '2026-05-03');
    expect(detail.growthMeasurements.single.heightCm, isNull);
    expect(detail.growthMeasurements.single.weightKg, '5.2');
    expect(detail.birth!.apgar5, 9);
  });
  test('missing birth and optional patient details remain readable', () {
    final detail = ChildDetail.fromJson({
      ...childDetailJson(),
      'birth': null,
      'child': {
        ...childJson(),
        'firstName': null,
        'dateOfBirth': null,
        'sex': null,
      },
    });
    expect(detail.birth, isNull);
    expect(detail.child.firstName, isNull);
    expect(detail.child.dateOfBirth, isNull);
  });
  test('mismatched pregnancy and child identity rejected', () async {
    adapter.body = pregnancyDetailJson();
    await expectLater(
      repository.pregnancy('other'),
      throwsA(isA<AppException>()),
    );
    adapter.body = childDetailJson();
    await expectLater(
      repository.child('record-1'),
      throwsA(isA<AppException>()),
    );
  });
  test(
    'malformed data and clinical measurements produce controlled errors',
    () async {
      for (final body in [
        '<html>private gateway</html>',
        {
          ...childDetailJson(),
          'growthMeasurements': [
            {
              'id': 'g',
              'measuredAt': '2026-01-01T10:00:00',
              'weightKg': 'private',
            },
          ],
        },
        {...pregnancyDetailJson(), 'lastMenstrualPeriod': '2026-02-30'},
      ]) {
        adapter.body = body;
        await expectLater(
          body is Map && body.containsKey('pregnancy')
              ? repository.pregnancy('pregnancy-1')
              : repository.child('child-1'),
          throwsA(isA<AppException>()),
        );
      }
    },
  );
  test('permission denial and missing record retain typed errors', () async {
    for (final status in [403, 404]) {
      adapter.status = status;
      adapter.body = {'message': 'Denied', 'code': 'ACCESS_DENIED'};
      await expectLater(
        repository.child('other'),
        throwsA(
          isA<AppException>().having((e) => e.statusCode, 'status', status),
        ),
      );
    }
  });
  test('logout cancels child request and discards late response', () async {
    final session = Session();
    final pending = PendingRepository();
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(() => session),
        maternalChildRepositoryProvider.overrideWithValue(pending),
      ],
    );
    final subscription = container.listen(
      childDetailProvider('child-1'),
      (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);
    session.signOut();
    expect(await container.read(childDetailProvider('child-1').future), isNull);
    expect(pending.tokens.single!.isCancelled, true);
    pending.pending.single.complete(ChildDetail.fromJson(childDetailJson()));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(childDetailProvider('child-1')).value, isNull);
    expect(
      await container.read(
        pregnanciesProvider(const MaternalChildListQuery()).future,
      ),
      isNull,
    );
    expect(
      await container.read(
        childrenProvider(const MaternalChildListQuery()).future,
      ),
      isNull,
    );
    expect(
      await container.read(pregnancyDetailProvider('pregnancy-1').future),
      isNull,
    );
    expect(pending.calls, 1);
    subscription.close();
    container.dispose();
  });
  test(
    'account switch cancels old request and retains only new response',
    () async {
      final session = Session();
      final pending = PendingRepository();
      final container = ProviderContainer(
        overrides: [
          sessionControllerProvider.overrideWith(() => session),
          maternalChildRepositoryProvider.overrideWithValue(pending),
        ],
      );
      final subscription = container.listen(
        childDetailProvider('child-1'),
        (_, _) {},
      );
      await Future<void>.delayed(Duration.zero);
      session.changeAccount();
      await Future<void>.delayed(Duration.zero);
      expect(pending.tokens.first!.isCancelled, true);
      expect(pending.calls, 2);
      pending.pending[0].complete(ChildDetail.fromJson(childDetailJson()));
      pending.pending[1].complete(
        ChildDetail.fromJson({
          ...childDetailJson(),
          'child': {...childJson(), 'firstName': 'New account'},
        }),
      );
      final detail = await container.read(
        childDetailProvider('child-1').future,
      );
      expect(detail!.child.firstName, 'New account');
      subscription.close();
      container.dispose();
    },
  );
}
