class Post {
  final String id;
  final String ownerId;
  final String username;
  final String? userAvatar;
  final String caption;
  final String? location;
  final DateTime timestamp;
  int likes;
  int commentCount;
  bool isLiked;
  final String? imageUrl;
  final String? videoUrl;
  final String? crossPostMessage;

  /// 'image' | 'text' | 'video'.
  /// Falls back to inferring from imageUrl/videoUrl for legacy posts that
  /// were created before this field existed.
  final String postType;

  Post({
    required this.id,
    required this.ownerId,
    required this.username,
    this.userAvatar,
    required this.caption,
    this.location,
    required this.timestamp,
    required this.likes,
    required this.commentCount,
    required this.isLiked,
    this.imageUrl,
    this.videoUrl,
    this.crossPostMessage,
    String? postType,
  }) : postType = postType ?? _inferType(imageUrl, videoUrl);

  static String _inferType(String? imageUrl, String? videoUrl) {
    if (videoUrl != null && videoUrl.isNotEmpty) return 'video';
    if (imageUrl != null && imageUrl.isNotEmpty) return 'image';
    return 'text';
  }

  bool get isImagePost => postType == 'image';
  bool get isVideoPost => postType == 'video';
  bool get isTextPost => postType == 'text';

  String get timeAgo {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 7) {
      return '${difference.inDays} days ago';
    }
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    }
    return 'Just now';
  }

  /// Build a Post from a Firestore document map + id.
  factory Post.fromMap(String id, Map<String, dynamic> data) {
    final likesList = List<String>.from(data['likes'] ?? []);
    return Post(
      id: id,
      ownerId: data['ownerId'] ?? '',
      username: data['username'] ?? '',
      userAvatar: data['userAvatar'],
      caption: data['caption'] ?? '',
      location: data['location'],
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as dynamic).toDate()
          : DateTime.now(),
      likes: likesList.length,
      commentCount: data['commentCount'] ?? 0,
      isLiked: false, // caller should override once currentUserId is known
      imageUrl: data['imageUrl'],
      videoUrl: data['videoUrl'],
      crossPostMessage: data['crossPostMessage'],
      postType: data['postType'],
    );
  }
}
