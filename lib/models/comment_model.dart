// lib/models/comment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String commentId;
  final String postId;
  final String authorId;
  final String authorUsername;
  final String authorPhotoUrl;
  final String text;
  final DateTime createdAt;
  final List<String> likedBy;

  CommentModel({
    required this.commentId,
    required this.postId,
    required this.authorId,
    required this.authorUsername,
    required this.authorPhotoUrl,
    required this.text,
    required this.createdAt,
    this.likedBy = const [],
  });

  int get likeCount => likedBy.length;
  bool isLikedBy(String userId) => likedBy.contains(userId);

  // No longer needs postId passed in separately — it's stored in the doc itself
  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      commentId: doc.id,
      postId: data['postId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorUsername: data['authorUsername'] ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likedBy: List<String>.from(data['likedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorUsername': authorUsername,
      'authorPhotoUrl': authorPhotoUrl,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'likedBy': likedBy,
    };
  }
}
