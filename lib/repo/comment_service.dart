import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/comment.dart';
import '../model/notification_model.dart';
import '../services/notification_service.dart';

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _commentsRef(String postId) =>
      _firestore.collection('posts').doc(postId).collection('comments');

  Future<void> addComment({
    required String postId,
    required String userId,
    required String username,
    required String? avatar,
    required String text,
    required String postOwnerId,
    required String senderId,
  }) async {
    final comment = Comment(
      id: '',
      postId: postId,
      userId: userId,
      username: username,
      userAvatar: avatar,
      text: text,
      timestamp: DateTime.now(),
    );
    await _commentsRef(postId).add(comment.toMap());
    await _firestore.collection('posts').doc(postId).update({
      'commentCount': FieldValue.increment(1),
    });

    if (postOwnerId != userId) {
      await NotificationService.createNotification(
        toUserId: postOwnerId,
        fromUserId: senderId,
        fromUsername: username,
        fromUserPhotoUrl: avatar ?? '',
        type: NotificationType.comment,
        postId: postId,
      );
    }
  }

  Stream<List<Comment>> getComments(String postId) {
    return _commentsRef(postId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Comment.fromFirestore(doc, postId))
              .toList(),
        );
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _commentsRef(postId).doc(commentId).delete();
    await _firestore.collection('posts').doc(postId).update({
      'commentCount': FieldValue.increment(-1),
    });
  }
}
