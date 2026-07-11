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
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CommentModel.fromFirestore(doc))
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

    // 1. Save the comment in the top-level collection
    await _firestore.collection('comments').add(comment.toMap());

    // 2. Bump the post's commentCount
    final postRef = _firestore.collection('posts').doc(postId);
    await postRef.update({'commentCount': FieldValue.increment(1)});

    // 3. Notify the post owner (unless commenting on your own post)
    final postSnap = await postRef.get();
    final postOwnerId =
        (postSnap.data() as Map<String, dynamic>?)?['authorId'] as String?;

    if (postOwnerId != null && postOwnerId != authorId) {
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

  @override
  Future<void> deleteComment(String commentId, String userId) async {
    final commentRef = _firestore.collection('comments').doc(commentId);
    final snap = await commentRef.get();
    final data = snap.data() as Map<String, dynamic>?;

    if (data == null) return;

    // Only the comment's author can delete it
    if (data['authorId'] != userId) {
      throw Exception('You can only delete your own comments');
    }

    final postId = data['postId'] as String;

    await commentRef.delete();

    await _firestore.collection('posts').doc(postId).update({
      'commentCount': FieldValue.increment(-1),
    });
  }

  @override
  Future<void> toggleLikeComment(String commentId, String userId) async {
    final commentRef = _firestore.collection('comments').doc(commentId);
    final snap = await commentRef.get();
    final data = snap.data() as Map<String, dynamic>?;
    final likedBy = List<String>.from(data?['likedBy'] ?? []);

    if (likedBy.contains(userId)) {
      await commentRef.update({
        'likedBy': FieldValue.arrayRemove([userId]),
      });
    } else {
      await commentRef.update({
        'likedBy': FieldValue.arrayUnion([userId]),
      });
    }
  }

  @override
  Future<int> getCommentCount(String postId) async {
    final postSnap = await _firestore.collection('posts').doc(postId).get();
    final data = postSnap.data() as Map<String, dynamic>?;
    return data?['commentCount'] ?? 0;
  }
}
