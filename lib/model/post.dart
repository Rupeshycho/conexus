import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  String ownerId;
  String username;
  String? userAvatar;
  String caption;
  String? location;
  DateTime timestamp;
  int likes;
  int commentCount;
  bool isLiked;
  String? imageUrl;
  String? crossPostMessage;

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
    this.crossPostMessage,
  });

  factory Post.fromFirestore(DocumentSnapshot doc, String currentUserId) {
    final data = doc.data() as Map<String, dynamic>;
    final likesList = List<String>.from(data['likes'] ?? []);
    return Post(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      username: data['username'] ?? '',
      userAvatar: data['userAvatar'],
      caption: data['caption'] ?? '',
      location: data['location'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: likesList.length,
      commentCount: data['commentCount'] ?? 0,
      isLiked: likesList.contains(currentUserId),
      imageUrl: data['imageUrl'],
      crossPostMessage: data['crossPostMessage'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'username': username,
      'userAvatar': userAvatar,
      'caption': caption,
      'location': location,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': [],
      'commentCount': 0,
      'imageUrl': imageUrl,
      'crossPostMessage': crossPostMessage,
    };
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays > 7) {
      return '${diff.inDays} days ago';
    }
    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    }
    return 'Just now';
  }
}
