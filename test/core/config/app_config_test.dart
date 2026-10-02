import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/core/config/app_config.dart';

void main() {
  test('development defaults to Android emulator', () {
    final config = AppConfig.fromValues(environment: 'dev', apiBaseUrl: '');
    expect(config.apiBaseUrl.host, '10.0.2.2');
    expect(config.isProduction, isFalse);
  });
  test('production requires explicit HTTPS API', () {
    for (final url in [
      '',
      'http://api.example.com/api/v1',
      'https://api.example.com',
      'https://user:pass@api.example.com/api/v1',
    ]) {
      expect(
        () => AppConfig.fromValues(environment: 'prod', apiBaseUrl: url),
        throwsArgumentError,
      );
    }
    expect(
      AppConfig.fromValues(
        environment: 'prod',
        apiBaseUrl: 'https://api.example.com/api/v1',
      ).isProduction,
      isTrue,
    );
  });
  test('unknown environment fails fast', () {
    expect(
      () => AppConfig.fromValues(environment: 'staging', apiBaseUrl: ''),
      throwsArgumentError,
    );
  });
}
