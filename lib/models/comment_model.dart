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

  CommentModel({
    required this.commentId,
    required this.postId,
    required this.authorId,
    required this.authorUsername,
    required this.authorPhotoUrl,
    required this.text,
    required this.createdAt,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc, String postId) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      commentId: doc.id,
      postId: postId,
      authorId: data['authorId'] ?? '',
      authorUsername: data['authorUsername'] ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorUsername': authorUsername,
      'authorPhotoUrl': authorPhotoUrl,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
