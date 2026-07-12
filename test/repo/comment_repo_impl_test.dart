import 'package:conexus/models/notification_model.dart';
import 'package:conexus/repo/notification_repo.dart';

class FakeNotificationRepo implements NotificationRepo {
  final List<Map<String, dynamic>> createdNotifications = [];

  @override
  Future<void> createNotification({
    required NotificationType type,
    required String postId,
    required String fromUserId,
    required String fromUsername,
    required String fromUserPhotoUrl,
    required String toUserId,
  }) async {
    createdNotifications.add({
      'type': type,
      'postId': postId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
    });
  }

  @override
  Stream<List<NotificationModel>> getNotifications(String userId) =>
      const Stream.empty();

  @override
  Future<void> markAsRead(String notificationId) async {}
}
