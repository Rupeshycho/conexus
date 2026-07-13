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
  final int commentCount;
  final DateTime createdAt;
  final List<String> likedBy;
  final bool isSaved;

  PostModel({
    required this.postId,
    required this.authorId,
    required this.authorUsername,
    required this.authorPhotoUrl,
    required this.type,
    this.mediaUrl,
    this.caption = '',
    this.commentCount = 0,
    required this.createdAt,
    this.likedBy = const [],
    this.isSaved = false,
  });

  int get likeCount => likedBy.length;

  bool isLikedBy(String userId) => likedBy.contains(userId);

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
      commentCount: data['commentCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likedBy: List<String>.from(data['likedBy'] ?? []),
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
      'commentCount': commentCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'likedBy': likedBy,
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
    int? commentCount,
    DateTime? createdAt,
    List<String>? likedBy,
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
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      likedBy: likedBy ?? this.likedBy,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}
