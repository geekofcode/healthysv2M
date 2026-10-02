import 'package:healthys_api/healthys_api.dart';
import 'package:test/test.dart';

void main() {
  test('reads the backend validation error envelope', () {
    final response = ErrorResponse.fromJson({
      'timestamp': '2026-10-02T14:00:00Z',
      'status': 400,
      'code': 'VALIDATION_FAILED',
      'message': 'Invalid request',
      'correlationId': 'request-123',
      'violations': [
        {'field': 'firstName', 'message': 'Required'},
      ],
    });

    expect(response.status, 400);
    expect(response.correlationId, 'request-123');
    expect(response.violations.single.field, 'firstName');
    expect(response.toJson()['code'], 'VALIDATION_FAILED');
  });
}
