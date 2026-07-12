import 'package:cloud_firestore/cloud_firestore.dart';

enum PostType { text, image, video }

class PostModel {
  final String postId;
  final String authorId;
  final String authorUsername;
  final String authorPhotoUrl;
  final PostType type;
  final String? mediaUrl;
  final String caption;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final bool isLiked;
  final bool isSaved;

  PostModel({
    required this.postId,
    required this.authorId,
    required this.authorUsername,
    required this.authorPhotoUrl,
    required this.type,
    this.mediaUrl,
    this.caption = '',
    this.likeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.isLiked = false,
    this.isSaved = false,
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      postId: doc.id,
      authorId: data['authorId'] ?? '',
      authorUsername: data['authorUsername'] ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] ?? '',
      type: PostType.values.firstWhere(
            (e) => e.toString() == data['type'],
        orElse: () => PostType.text,
      ),
      mediaUrl: data['mediaUrl'],
      caption: data['caption'] ?? '',
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isLiked: data['isLiked'] ?? false,
      isSaved: data['isSaved'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorUsername': authorUsername,
      'authorPhotoUrl': authorPhotoUrl,
      'type': type.toString(),
      'mediaUrl': mediaUrl,
      'caption': caption,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  PostModel copyWith({
    String? postId,
    String? authorId,
    String? authorUsername,
    String? authorPhotoUrl,
    PostType? type,
    String? mediaUrl,
    String? caption,
    int? likeCount,
    int? commentCount,
    DateTime? createdAt,
    bool? isLiked,
    bool? isSaved,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorUsername: authorUsername ?? this.authorUsername,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      caption: caption ?? this.caption,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}