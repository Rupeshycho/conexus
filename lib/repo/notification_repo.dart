import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import 'notification_repo.dart';

class NotificationRepoImpl implements NotificationRepo {
  final FirebaseFirestore _firestore;

  NotificationRepoImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList());
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    // Find the notification
    final querySnapshot = await _firestore
        .collectionGroup('notifications')
        .where(FieldPath.documentId, isEqualTo: notificationId)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      await querySnapshot.docs.first.reference.update({
        'isRead': true,
      });
    }
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    final querySnapshot = await _firestore
        .collectionGroup('notifications')
        .where(FieldPath.documentId, isEqualTo: notificationId)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      await querySnapshot.docs.first.reference.delete();
    }
  }

  @override
  Future<void> createNotification(NotificationModel notification) async {
    await _firestore
        .collection('users')
        .doc(notification.userId)
        .collection('notifications')
        .add(notification.toMap());
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .count()
        .get();
    return snapshot.count;
  }
}