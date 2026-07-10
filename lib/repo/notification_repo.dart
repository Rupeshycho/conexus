// lib/repo/notification_repo.dart
import '../models/notification_model.dart';

abstract class NotificationRepo {
  Stream<List<NotificationModel>> getNotifications(String userId);

  Future<void> createNotification({
    required NotificationType type,
    required String postId,
    required String fromUserId,
    required String fromUsername,
    required String fromUserPhotoUrl,
    required String toUserId,
  });

  Future<void> markAsRead(String notificationId);
}
