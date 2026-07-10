import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  like,
  comment,
  follow,
  mention,
  repost,
  friendRequest,
  friendAccepted,
}

class NotificationModel {
  final String notificationId;
  final String userId; // Who receives the notification
  final String? actorId; // Who performed the action
  final String? actorUsername;
  final String? actorPhotoUrl;
  final NotificationType type;
  final String? postId;
  final String? postImageUrl;
  final String? commentText;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  NotificationModel({
    required this.notificationId,
    required this.userId,
    this.actorId,
    this.actorUsername,
    this.actorPhotoUrl,
    required this.type,
    this.postId,
    this.postImageUrl,
    this.commentText,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      notificationId: doc.id,
      userId: data['userId'] ?? '',
      actorId: data['actorId'],
      actorUsername: data['actorUsername'],
      actorPhotoUrl: data['actorPhotoUrl'],
      type: NotificationType.values.firstWhere(
            (e) => e.toString() == data['type'],
        orElse: () => NotificationType.like,
      ),
      postId: data['postId'],
      postImageUrl: data['postImageUrl'],
      commentText: data['commentText'],
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'actorId': actorId,
      'actorUsername': actorUsername,
      'actorPhotoUrl': actorPhotoUrl,
      'type': type.toString(),
      'postId': postId,
      'postImageUrl': postImageUrl,
      'commentText': commentText,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }

  NotificationModel copyWith({
    String? notificationId,
    String? userId,
    String? actorId,
    String? actorUsername,
    String? actorPhotoUrl,
    NotificationType? type,
    String? postId,
    String? postImageUrl,
    String? commentText,
    String? message,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationModel(
      notificationId: notificationId ?? this.notificationId,
      userId: userId ?? this.userId,
      actorId: actorId ?? this.actorId,
      actorUsername: actorUsername ?? this.actorUsername,
      actorPhotoUrl: actorPhotoUrl ?? this.actorPhotoUrl,
      type: type ?? this.type,
      postId: postId ?? this.postId,
      postImageUrl: postImageUrl ?? this.postImageUrl,
      commentText: commentText ?? this.commentText,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}