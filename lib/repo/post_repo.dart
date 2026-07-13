import 'dart:io';

import 'package:conexus/model/post_model.dart';

abstract class PostRepo {
  Stream<List<PostModel>> getFeed(String viewerId);
  Stream<List<PostModel>> getUserPosts(String userId, String viewerId);

  Future<void> createTextPost({
    required String authorId,
    required String authorUsername,
    required String authorPhotoUrl,
    required String caption,
  });

  Future<void> createImagePost({
    required String authorId,
    required String authorUsername,
    required String authorPhotoUrl,
    required File file,
    required String caption,
  });

  Future<void> createVideoPost({
    required String authorId,
    required String authorUsername,
    required String authorPhotoUrl,
    required File file,
    required String caption,
  });

  Future<void> markNotInterested(String userId, String postId);
  Future<void> reportPost(String userId, String postId, String reason);

  Future<void> toggleLikePost({
    required String postId,
    required String userId,
    required String username,
    required String userPhotoUrl,
  });

  Future<void> editPost({
    required String postId,
    required String userId,
    required String caption,
  });

  Future<void> deletePost(String postId, String userId);

  Stream<PostModel?> getPostById(String postId);
}
