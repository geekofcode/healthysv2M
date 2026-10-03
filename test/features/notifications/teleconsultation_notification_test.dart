import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/features/notifications/domain/notifications.dart';

void main() {
  test(
    'authenticated video session reference opens the protected room route',
    () {
      const id = '12345678-1234-4234-8234-123456789abc';
      final notification = HealthysNotification(
        id: id,
        type: 'TELECONSULTATION_READY',
        body: 'A consultation is available.',
        resourceType: 'VIDEO_SESSION',
        resourceId: id,
        actionUrl: 'https://untrusted.example/room',
        priority: 'NORMAL',
        createdAt: DateTime.utc(2026, 10, 3),
        status: 'CREATED',
        read: false,
      );
      expect(notificationDestination(notification), '/teleconsultations/$id');
    },
  );
}
