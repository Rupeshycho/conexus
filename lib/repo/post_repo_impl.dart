// lib/repo/post_repo_impl.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../services/cloudinary_service.dart';
import 'post_repo.dart';

class PostRepoImpl implements PostRepo {
  final FirebaseFirestore _firestore;

  PostRepoImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<PostModel>> getFeed() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList());
  }

  @override
  Future<void> createTextPost({
    required String authorId,
    required String authorUsername,
    required String authorPhotoUrl,
    required String caption,
  }) async {
    final post = PostModel(
      postId: '',
      authorId: authorId,
      authorUsername: authorUsername,
      authorPhotoUrl: authorPhotoUrl,
      type: PostType.text,
      caption: caption,
      createdAt: DateTime.now(),
    );
    await _firestore.collection('posts').add(post.toMap());
  }

  @override
  Future<void> createImagePost({
    required String authorId,
    required String authorUsername,
    required String authorPhotoUrl,
    required File file,
    required String caption,
  }) async {
    final imageUrl = await CloudinaryService.uploadImage(file);

    final post = PostModel(
      postId: '',
      authorId: authorId,
      authorUsername: authorUsername,
      authorPhotoUrl: authorPhotoUrl,
      type: PostType.image,
      mediaUrl: imageUrl,
      caption: caption,
      createdAt: DateTime.now(),
    );
    await _firestore.collection('posts').add(post.toMap());
  }

  @override
  Future<void> createVideoPost({
    required String authorId,
    required String authorUsername,
    required String authorPhotoUrl,
    required File file,
    required String caption,
  }) async {
    final videoUrl = await CloudinaryService.uploadVideo(file);

    final post = PostModel(
      postId: '',
      authorId: authorId,
      authorUsername: authorUsername,
      authorPhotoUrl: authorPhotoUrl,
      type: PostType.video,
      mediaUrl: videoUrl,
      caption: caption,
      createdAt: DateTime.now(),
    );
    await _firestore.collection('posts').add(post.toMap());
  }

  @override
  Future<void> markNotInterested(String userId, String postId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notInterested')
        .doc(postId)
        .set({'postId': postId, 'markedAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> reportPost(String userId, String postId, String reason) async {
    await _firestore.collection('reports').add({
      'postId': postId,
      'reportedBy': userId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}