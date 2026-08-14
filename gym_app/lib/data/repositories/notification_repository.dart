import '../datasources/firestore_datasource.dart';
import '../models/app_notification_model.dart';

class NotificationRepository {
  final FirestoreDataSource _firestore;

  NotificationRepository({required FirestoreDataSource firestoreDataSource})
      : _firestore = firestoreDataSource;

  Stream<List<AppNotificationModel>> watchNotifications(String userId) {
    return _firestore.watchNotifications(userId);
  }

  Future<void> markAllAsRead(String userId) {
    return _firestore.markNotificationsRead(userId);
  }
}
