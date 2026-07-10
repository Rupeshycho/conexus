// lib/repo/comment_repo_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/comment_model.dart';
import '../models/notification_model.dart';
import 'comment_repo.dart';
import 'notification_repo.dart';

class CommentRepoImpl implements CommentRepo {
  final FirebaseFirestore _firestore;
  final NotificationRepo _notificationRepo;

  CommentRepoImpl({
    required NotificationRepo notificationRepo,
    FirebaseFirestore? firestore,
  }) : _notificationRepo = notificationRepo,
       _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<CommentModel>> getComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false) // oldest first, like Instagram
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CommentModel.fromFirestore(doc, postId))
              .toList(),
        );
  }

  @override
  Future<void> addComment({
    required String postId,
    required String authorId,
    required String authorUsername,
    required String authorPhotoUrl,
    required String text,
    required String postOwnerId,
  }) async {
    final comment = CommentModel(
      commentId: '',
      postId: postId,
      authorId: authorId,
      authorUsername: authorUsername,
      authorPhotoUrl: authorPhotoUrl,
      text: text,
      createdAt: DateTime.now(),
    );

    // 1. Save the comment itself
    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add(comment.toMap());

    // 2. Bump the post's commentCount
    await _firestore.collection('posts').doc(postId).update({
      'commentCount': FieldValue.increment(1),
    });

    // 3. Notify the post owner (skip notifying yourself if you comment on your own post)
    if (postOwnerId != authorId) {
      await _notificationRepo.createNotification(
        type: NotificationType.comment,
        postId: postId,
        fromUserId: authorId,
        fromUsername: authorUsername,
        fromUserPhotoUrl: authorPhotoUrl,
        toUserId: postOwnerId,
      );
    }
  }
}
