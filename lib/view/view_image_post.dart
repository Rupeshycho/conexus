import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../model/comment.dart';
import '../model/notification_model.dart';
import '../repo/comment_service.dart';
import '../repo/notification_service.dart';

class ViewImagePost extends StatefulWidget {
  final String postId;
  final String currentUserId;
  final String currentUsername;
  final String? currentUserAvatar;

  const ViewImagePost({
    super.key,
    required this.postId,
    required this.currentUserId,
    required this.currentUsername,
    this.currentUserAvatar,
  });

  @override
  State<ViewImagePost> createState() => _ViewImagePostState();
}

class _ViewImagePostState extends State<ViewImagePost> {
  final CommentService _commentService = CommentService();
  final TextEditingController _commentController = TextEditingController();
  bool _isLiking = false;

  Future<void> _toggleLike(DocumentSnapshot postDoc) async {
    if (_isLiking) return;
    setState(() => _isLiking = true);
    try {
      final postRef =
          FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      final data = postDoc.data() as Map<String, dynamic>? ?? {};
      final likes = List<String>.from(data['likes'] ?? []);
      final ownerId = data['ownerId'] ?? '';

      if (likes.contains(widget.currentUserId)) {
        await postRef.update({
          'likes': FieldValue.arrayRemove([widget.currentUserId])
        });
        if (mounted) {
          NotificationService.showSnackBar(context, 'Unliked!');
        }
        // No notification on unlike — only like/comment/follow are supported.
      } else {
        await postRef.update({
          'likes': FieldValue.arrayUnion([widget.currentUserId])
        });
        if (mounted) {
          NotificationService.showSnackBar(context, 'Liked!');
        }
        await NotificationService.createNotification(
          toUserId: ownerId,
          fromUserId: widget.currentUserId,
          fromUsername: widget.currentUsername,
          fromUserPhotoUrl: widget.currentUserAvatar ?? '',
          type: NotificationType.like,
          postId: widget.postId,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update like: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .delete();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final postDoc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .get();
    final ownerId = postDoc.data()?['ownerId'] ?? '';
    await _commentService.addComment(
      postId: widget.postId,
      userId: widget.currentUserId,
      username: widget.currentUsername,
      avatar: widget.currentUserAvatar,
      text: text,
      postOwnerId: ownerId,
      senderId: widget.currentUserId,
    );
    _commentController.clear();
    if (mounted) {
      NotificationService.showSnackBar(context, 'Comment added!');
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Delete this comment?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _commentService.deleteComment(widget.postId, commentId);
      // No notification on comment deletion — only like/comment/follow are supported.
      if (mounted) {
        NotificationService.showSnackBar(context, 'Comment deleted!');
      }
    }
  }

  void _sharePost(DocumentSnapshot snapshot) {
    // No notification on share — only like/comment/follow are supported.
    NotificationService.showSnackBar(context, 'Shared!');
  }

  void _navigateToEdit(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    Navigator.pushNamed(
      context,
      '/edit_post',
      arguments: {
        'postId': widget.postId,
        'caption': data['caption'] ?? '',
        'location': data['location'],
        'crossPostMessage': data['crossPostMessage'],
        'isImagePost': true,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Post'),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .doc(widget.postId)
                .snapshots(),
            builder: (ctx, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final ownerId = snapshot.data!.get('ownerId') ?? '';
              if (ownerId != widget.currentUserId)
                return const SizedBox.shrink();
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _navigateToEdit(snapshot.data!),
                    tooltip: 'Edit post',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _deletePost,
                    tooltip: 'Delete post',
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300, width: 1.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData || !snapshot.data!.exists)
                  return const Center(child: CircularProgressIndicator());

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final caption = data['caption'] ?? '';
                final imageUrl = data['imageUrl'] ?? '';
                final likesList = List<String>.from(data['likes'] ?? []);
                final isLiked = likesList.contains(widget.currentUserId);
                final likeCount = likesList.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image, size: 100),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(caption, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : null,
                              size: 30),
                          onPressed: _isLiking
                              ? null
                              : () => _toggleLike(snapshot.data!),
                        ),
                        const SizedBox(width: 8),
                        Text('$likeCount ${likeCount == 1 ? 'like' : 'likes'}'),
                        const Spacer(),
                        if (isLiked)
                          TextButton(
                            onPressed: _isLiking
                                ? null
                                : () => _toggleLike(snapshot.data!),
                            child: const Text('Unlike',
                                style: TextStyle(color: Colors.red)),
                          ),
                        IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: () => _sharePost(snapshot.data!),
                            tooltip: 'Share'),
                      ],
                    ),
                    const Divider(),
                    const Text('Comments',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    StreamBuilder<List<Comment>>(
                      stream: _commentService.getComments(widget.postId),
                      builder: (ctx, commentSnapshot) {
                        if (commentSnapshot.hasError)
                          return Text('Error: ${commentSnapshot.error}');
                        if (!commentSnapshot.hasData)
                          return const Center(
                              child: CircularProgressIndicator());
                        final comments = commentSnapshot.data!;
                        if (comments.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                                'No comments yet. Be the first to comment!'),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: comments.length,
                          itemBuilder: (ctx, index) {
                            final comment = comments[index];
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(comment.username.isNotEmpty
                                    ? comment.username[0].toUpperCase()
                                    : '?'),
                              ),
                              title: Text(comment.username,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(comment.text),
                              trailing: comment.userId == widget.currentUserId
                                  ? IconButton(
                                      icon: const Icon(Icons.delete,
                                          size: 18, color: Colors.grey),
                                      onPressed: () =>
                                          _deleteComment(comment.id),
                                    )
                                  : null,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(
                              hintText: 'Write a comment...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: _addComment,
                            color: Colors.blue),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
