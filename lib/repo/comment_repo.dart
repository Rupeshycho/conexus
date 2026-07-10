import '../models/comment_model.dart';

abstract class CommentRepo {
  Stream<List<CommentModel>> getComments(String postId);
  Future<void> addComment({
    required String postId,
    required String authorId,
    required String authorUsername,
    required String authorPhotoUrl,
    required String text,
  });
  Future<void> deleteComment(String commentId, String userId);
  Future<void> toggleLikeComment(String commentId, String userId);
  Future<int> getCommentCount(String postId);
}