// lib/repo/notification_repo_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conexus/model/notification_model.dart';

import 'notification_repo.dart';

class NotificationRepoImpl implements NotificationRepo {
  final FirebaseFirestore _firestore;

  NotificationRepoImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList(),
        );
  }

  @override
  Future<void> createNotification({
    required NotificationType type,
    required String postId,
    required String fromUserId,
    required String fromUsername,
    required String fromUserPhotoUrl,
    required String toUserId,
  }) async {
    final notification = NotificationModel(
      notificationId: '',
      type: type,
      postId: postId,
      fromUserId: fromUserId,
      fromUsername: fromUsername,
      fromUserPhotoUrl: fromUserPhotoUrl,
      toUserId: toUserId,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('notifications').add(notification.toMap());
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  @override
  Future<void> markAllAsRead(
    String userId,
    List<String> notificationIds,
  ) async {
    final batch = _firestore.batch();
    for (final id in notificationIds) {
      final ref = _firestore.collection('notifications').doc(id);
      batch.update(ref, {'isRead': true});
    }
    await batch.commit();
  }
}
