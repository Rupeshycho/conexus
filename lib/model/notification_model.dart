import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String receiverId;
  final String senderId;
  final String type;
  final String? postId;
  final String message;
  final bool isRead;
  final DateTime timestamp;

  NotificationModel({
    required this.id,
    required this.receiverId,
    required this.senderId,
    required this.type,
    this.postId,
    required this.message,
    this.isRead = false,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'receiverId': receiverId,
      'senderId': senderId,
      'type': type,
      'postId': postId,
      'message': message,
      'isRead': isRead,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      receiverId: data['receiverId'] ?? '',
      senderId: data['senderId'] ?? '',
      type: data['type'] ?? '',
      postId: data['postId'],
      message: data['message'] ?? '',
      isRead: data['isRead'] ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
