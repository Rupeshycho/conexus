// lib/models/post_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum PostType { text, image, video }

class PostModel {
  final String postId;
  final String authorId;
  final String authorUsername;
  final String authorPhotoUrl;
  final PostType type;
  final String? mediaUrl;      // Cloudinary URL — null for text posts
  final String caption;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;

  PostModel({
    required this.postId,
    required this.authorId,
    required this.authorUsername,
    required this.authorPhotoUrl,
    required this.type,
    this.mediaUrl,
    required this.caption,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      postId: doc.id,
      authorId: data['authorId'] ?? '',
      authorUsername: data['authorUsername'] ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] ?? '',
      type: PostType.values.firstWhere(
            (e) => e.name == data['type'],
        orElse: () => PostType.text,
      ),
      mediaUrl: data['mediaUrl'],
      caption: data['caption'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorUsername': authorUsername,
      'authorPhotoUrl': authorPhotoUrl,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'caption': caption,
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': likeCount,
      'commentCount': commentCount,
    };
  }
}