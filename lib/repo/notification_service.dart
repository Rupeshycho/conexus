import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../model/notification_model.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  static Future<void> createNotification({
    required String receiverId,
    required String senderId,
    required String type,
    String? postId,
    required String message,
  }) async {
    // Self‑notifications are allowed
    final notification = NotificationModel(
      id: '',
      receiverId: receiverId,
      senderId: senderId,
      type: type,
      postId: postId,
      message: message,
      isRead: false,
      timestamp: DateTime.now(),
    );
    await _firestore.collection('notifications').add(notification.toMap());
  }

  static Stream<List<NotificationModel>> getNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList(),
        );
  }

  static Future<void> markRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  static Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }
}
