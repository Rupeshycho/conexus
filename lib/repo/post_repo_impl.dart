import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conexus/model/notification_model.dart';
import 'package:conexus/model/post_model.dart';

import '../services/cloudinary_service.dart';
import 'notification_repo.dart';
import 'post_repo.dart';

class PostRepoImpl implements PostRepo {
  final FirebaseFirestore _firestore;
  final NotificationRepo _notificationRepo;

  PostRepoImpl({
    required NotificationRepo notificationRepo,
    FirebaseFirestore? firestore,
  }) : _notificationRepo = notificationRepo,
       _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<PostModel>> getFeed(String viewerId) async* {
    yield* _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .asyncMap((snapshot) async {
          final posts = snapshot.docs
              .map((doc) => PostModel.fromFirestore(doc))
              .toList();

          final authorIds = posts.map((p) => p.authorId).toSet().toList();
          if (authorIds.isEmpty) return <PostModel>[];

          // Firestore's `whereIn` caps out at 10 values per query, so batch
          // the author lookups into chunks of 10.
          final Map<String, Map<String, dynamic>> authorData = {};
          for (var i = 0; i < authorIds.length; i += 10) {
            final end = (i + 10 > authorIds.length) ? authorIds.length : i + 10;
            final chunk = authorIds.sublist(i, end);
            final snap = await _firestore
                .collection('users')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
            for (final doc in snap.docs) {
              authorData[doc.id] = doc.data();
            }
          }

          return posts.where((post) {
            if (post.authorId == viewerId) return true;
            final data = authorData[post.authorId];
            final isPublic = data?['publicProfile'] ?? true;
            if (isPublic) return true;
            final followers = List<String>.from(data?['followers'] ?? []);
            return followers.contains(viewerId);
          }).toList();
        });
  }

  @override
  Stream<List<PostModel>> getUserPosts(String userId, String viewerId) async* {
    if (userId != viewerId) {
      final authorDoc = await _firestore.collection('users').doc(userId).get();
      final authorData = authorDoc.data();
      final isPublic = authorData?['publicProfile'] ?? true;
      final followers = List<String>.from(authorData?['followers'] ?? []);
      final canView = isPublic || followers.contains(viewerId);

      if (!canView) {
        yield <PostModel>[];
        return;
      }
    }

    yield* _firestore
        .collection('posts')
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList(),
        );
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

  @override
  Future<void> toggleLikePost({
    required String postId,
    required String userId,
    required String username,
    required String userPhotoUrl,
  }) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final snap = await postRef.get();
    final data = snap.data() as Map<String, dynamic>?;
    if (data == null) return;

    final likedBy = List<String>.from(data['likedBy'] ?? []);
    final isLiked = likedBy.contains(userId);

    if (isLiked) {
      await postRef.update({
        'likedBy': FieldValue.arrayRemove([userId]),
      });
      return;
    }

    await postRef.update({
      'likedBy': FieldValue.arrayUnion([userId]),
    });

    final postOwnerId = data['authorId'] as String?;
    if (postOwnerId != null && postOwnerId != userId) {
      await _notificationRepo.createNotification(
        type: NotificationType.like,
        postId: postId,
        fromUserId: userId,
        fromUsername: username,
        fromUserPhotoUrl: userPhotoUrl,
        toUserId: postOwnerId,
      );
    }
  }

  @override
  Future<void> editPost({
    required String postId,
    required String userId,
    required String caption,
  }) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final snap = await postRef.get();
    final data = snap.data() as Map<String, dynamic>?;
    if (data == null) return;

    if (data['authorId'] != userId) {
      throw Exception('You can only edit your own posts');
    }

    await postRef.update({
      'caption': caption,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deletePost(String postId, String userId) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final snap = await postRef.get();
    final data = snap.data() as Map<String, dynamic>?;
    if (data == null) return;

    if (data['authorId'] != userId) {
      throw Exception('You can only delete your own posts');
    }

    await postRef.delete();

    final commentsSnap = await _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .get();
    if (commentsSnap.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final doc in commentsSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  @override
  Stream<PostModel?> getPostById(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .snapshots()
        .map((doc) => doc.exists ? PostModel.fromFirestore(doc) : null);
  }
}
