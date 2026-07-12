import 'package:conexus/models/notification_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationModel', () {
    test('message getter formats comment notification correctly', () {
      final n = NotificationModel(
        notificationId: '1',
        type: NotificationType.comment,
        postId: 'p1',
        fromUserId: 'u1',
        fromUsername: 'rupesh',
        fromUserPhotoUrl: '',
        toUserId: 'u2',
        createdAt: DateTime.now(),
      );
      expect(n.message, 'rupesh commented on your post');
  });
    test('message getter formats like and follow notifications correctly', () {
      final like = NotificationModel(
        notificationId: '1',
        type: NotificationType.like,
        postId: 'p1',
        fromUserId: 'u1',
        fromUsername: 'jack',
        fromUserPhotoUrl: '',
        toUserId: 'u2',
        createdAt: DateTime.now(),
      );
      final follow = NotificationModel(
        notificationId: '2',
        type: NotificationType.follow,
        postId: '',
        fromUserId: 'u1',
        fromUsername: 'sara',
        fromUserPhotoUrl: '',
        toUserId: 'u2',
        createdAt: DateTime.now(),
      );

      expect(like.message, 'jack liked your post');
      expect(follow.message, 'sara started following you');
    });
}
