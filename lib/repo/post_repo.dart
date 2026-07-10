// lib/repo/post_repo.dart
import 'dart:io';
import '../models/post_model.dart';

abstract class PostRepo {
  Stream<List<PostModel>> getFeed();

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
}
