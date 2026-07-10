import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';
import 'comment_repo.dart';

class CommentRepoImpl implements CommentRepo {
  final FirebaseFirestore _firestore;

  CommentRepoImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<CommentModel>> getComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => CommentModel.fromFirestore(doc)).toList());
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

    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add(comment.toMap());

    // Increment comment count on post
    await _firestore.collection('posts').doc(postId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  @override
  Future<void> deleteComment(String commentId, String userId) async {
    // Find which post this comment belongs to
    final querySnapshot = await _firestore
        .collectionGroup('comments')
        .where(FieldPath.documentId, isEqualTo: commentId)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final postId = doc.data()['postId'];

      // Check if user is authorized
      if (doc.data()['authorId'] == userId) {
        await doc.reference.delete();

        // Decrement comment count
        await _firestore.collection('posts').doc(postId).update({
          'commentCount': FieldValue.increment(-1),
        });
      } else {
        throw Exception('Not authorized to delete this comment');
      }
    }
  }

  @override
  Future<void> toggleLikeComment(String commentId, String userId) async {
    // Find the comment
    final querySnapshot = await _firestore
        .collectionGroup('comments')
        .where(FieldPath.documentId, isEqualTo: commentId)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final likeRef = doc.reference.collection('likes').doc(userId);

      final likeDoc = await likeRef.get();
      if (likeDoc.exists) {
        await likeRef.delete();
        await doc.reference.update({
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        await likeRef.set({'userId': userId, 'createdAt': FieldValue.serverTimestamp()});
        await doc.reference.update({
          'likeCount': FieldValue.increment(1),
        });
      }
    }
  }

  @override
  Future<int> getCommentCount(String postId) async {
    final snapshot = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .count()
        .get();
    return snapshot.count;
  }
}