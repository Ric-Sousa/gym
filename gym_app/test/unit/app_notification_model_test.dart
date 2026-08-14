import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/app_notification_model.dart';

void main() {
  test('creates an unread persistent notification from a map', () {
    final notification = AppNotificationModel.fromMap('', {
      'userId': 'user-1',
      'type': 'payment_failed',
      'title': 'Pagamento recusado',
      'body': 'Regulariza o pagamento.',
      'read': false,
      'createdAt': '2026-08-14T10:00:00.000Z',
    });

    expect(notification.userId, 'user-1');
    expect(notification.type, 'payment_failed');
    expect(notification.read, isFalse);
    expect(notification.createdAt, DateTime.parse('2026-08-14T10:00:00.000Z'));
  });

  test('copyWith marks a notification as read without changing its content', () {
    final notification = AppNotificationModel(
      id: 'n1',
      userId: 'user-1',
      type: 'access_change',
      title: 'Acesso ativado',
      body: 'Já podes entrar.',
      createdAt: DateTime(2026, 8, 14),
    );

    final read = notification.copyWith(read: true);
    expect(read.read, isTrue);
    expect(read.title, notification.title);
    expect(read.body, notification.body);
  });
}
