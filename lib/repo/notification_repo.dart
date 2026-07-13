// lib/repo/notification_repo.dart
import 'package:conexus/model/notification_model.dart';

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

  Future<void> markAllAsRead(String userId, List<String> notificationIds);
}
