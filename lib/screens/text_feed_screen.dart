import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../model/post.dart';
import '../repo/comment_service.dart';
import '../repo/notification_service.dart';
import '../widgets/text_post_card.dart';

class TextFeedScreen extends StatefulWidget {
  const TextFeedScreen({super.key});

  @override
  State<TextFeedScreen> createState() => _TextFeedScreenState();
}

class _TextFeedScreenState extends State<TextFeedScreen> {
  final String currentUserId = 'user123';
  final String currentUsername = 'JohnDoe';
  final String? currentUserAvatar = null;

  void _toggleLike(String postId, bool isLiked) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    if (isLiked) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([currentUserId]),
      });
      if (mounted) NotificationService.showSnackBar(context, 'Unliked!');
      final postDoc = await postRef.get();
      final ownerId = postDoc.data()?['ownerId'] ?? '';
      await NotificationService.createNotification(
        receiverId: ownerId,
        senderId: currentUserId,
        type: 'unlike',
        postId: postId,
        message: '$currentUsername removed like from your post',
      );
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([currentUserId]),
      });
      if (mounted) NotificationService.showSnackBar(context, 'Liked!');
      final postDoc = await postRef.get();
      final ownerId = postDoc.data()?['ownerId'] ?? '';
      await NotificationService.createNotification(
        receiverId: ownerId,
        senderId: currentUserId,
        type: 'like',
        postId: postId,
        message: '$currentUsername liked your post',
      );
    }
  }

  void _navigateToTextPost(Post post) {
    Navigator.pushNamed(
      context,
      '/view_text_post',
      arguments: {'post': post, 'currentUserId': currentUserId},
    );
  }

  void _sharePost(String postId) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final postDoc = await postRef.get();
    final ownerId = postDoc.data()?['ownerId'] ?? '';
    await NotificationService.createNotification(
      receiverId: ownerId,
      senderId: currentUserId,
      type: 'share',
      postId: postId,
      message: '$currentUsername shared your post',
    );
    if (mounted) NotificationService.showSnackBar(context, 'Shared!');
  }

  void _navigateToEdit(Post post) {
    Navigator.pushNamed(
      context,
      '/edit_post',
      arguments: {
        'postId': post.id,
        'caption': post.caption,
        'location': post.location,
        'crossPostMessage': post.crossPostMessage,
        'isImagePost': false,
      },
    );
  }

  void _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      final ownerId = postDoc.data()?['ownerId'] ?? '';

      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();

      await NotificationService.createNotification(
        receiverId: ownerId,
        senderId: currentUserId,
        type: 'delete_post',
        postId: postId,
        message: '$currentUsername deleted a post',
      );
      if (mounted) NotificationService.showSnackBar(context, 'Post deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('imageUrl', isEqualTo: null)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final likesList = List<String>.from(data['likes'] ?? []);
            return Post(
              id: doc.id,
              ownerId: data['ownerId'] ?? '',
              username: data['username'] ?? '',
              userAvatar: data['userAvatar'],
              caption: data['caption'] ?? '',
              location: data['location'],
              timestamp:
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              likes: likesList.length,
              commentCount: data['commentCount'] ?? 0,
              isLiked: likesList.contains(currentUserId),
              imageUrl: data['imageUrl'],
              crossPostMessage: data['crossPostMessage'],
            );
          }).toList();

          if (posts.isEmpty) {
            return const Center(child: Text('No text posts yet. Create one!'));
          }

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return TextPostCard(
                post: post,
                currentUserId: currentUserId,
                onLikeTap: () => _toggleLike(post.id, post.isLiked),
                onUnlikeTap: () => _toggleLike(post.id, post.isLiked),
                onCommentTap: () => _navigateToTextPost(post),
                onShareTap: () => _sharePost(post.id),
                onEditTap: () => _navigateToEdit(post),
                onDeleteTap: () => _deletePost(post.id),
                onAddComment: (text) async {
                  final postDoc = await FirebaseFirestore.instance
                      .collection('posts')
                      .doc(post.id)
                      .get();
                  final ownerId = postDoc.data()?['ownerId'] ?? '';
                  await CommentService().addComment(
                    postId: post.id,
                    userId: currentUserId,
                    username: currentUsername,
                    avatar: currentUserAvatar,
                    text: text,
                    postOwnerId: ownerId,
                    senderId: currentUserId,
                  );
                  if (mounted)
                    NotificationService.showSnackBar(context, 'Comment added!');
                },
              );
            },
          );
        },
      ),
    );
  }
}
