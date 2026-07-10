// lib/models/notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { comment, like, follow }

class NotificationModel {
  final String notificationId;
  final NotificationType type;
  final String postId;
  final String fromUserId;
  final String fromUsername;
  final String fromUserPhotoUrl;
  final String toUserId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.notificationId,
    required this.type,
    required this.postId,
    required this.fromUserId,
    required this.fromUsername,
    required this.fromUserPhotoUrl,
    required this.toUserId,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      notificationId: doc.id,
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.comment,
      ),
      postId: data['postId'] ?? '',
      fromUserId: data['fromUserId'] ?? '',
      fromUsername: data['fromUsername'] ?? '',
      fromUserPhotoUrl: data['fromUserPhotoUrl'] ?? '',
      toUserId: data['toUserId'] ?? '',
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'postId': postId,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'fromUserPhotoUrl': fromUserPhotoUrl,
      'toUserId': toUserId,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String get message {
    switch (type) {
      case NotificationType.comment:
        return '$fromUsername commented on your post';
      case NotificationType.like:
        return '$fromUsername liked your post';
      case NotificationType.follow:
        return '$fromUsername started following you';
    }
  }
}
