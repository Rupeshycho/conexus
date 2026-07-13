import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../model/comment.dart';
import '../model/notification_model.dart';
import '../model/post.dart';
import '../repo/comment_service.dart';
import '../repo/notification_service.dart';

class ViewTextPost extends StatefulWidget {
  final Post post;
  final String currentUserId;
  final String currentUsername;
  final String? currentUserAvatar;

  const ViewTextPost({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.currentUsername,
    this.currentUserAvatar,
  });

  @override
  State<ViewTextPost> createState() => _ViewTextPostState();
}

class _ViewTextPostState extends State<ViewTextPost> {
  late Post _post;
  bool _isLiking = false;
  final CommentService _commentService = CommentService();
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    setState(() => _isLiking = true);
    try {
      final postRef =
          FirebaseFirestore.instance.collection('posts').doc(_post.id);
      final ownerId = _post.ownerId;

      if (_post.isLiked) {
        await postRef.update({
          'likes': FieldValue.arrayRemove([widget.currentUserId])
        });
        setState(() {
          _post.isLiked = false;
          _post.likes--;
        });
        if (mounted) {
          NotificationService.showSnackBar(context, 'Unliked!');
        }
        // No notification on unlike — only like/comment/follow are supported.
      } else {
        await postRef.update({
          'likes': FieldValue.arrayUnion([widget.currentUserId])
        });
        setState(() {
          _post.isLiked = true;
          _post.likes++;
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
          postId: _post.id,
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
    await FirebaseFirestore.instance.collection('posts').doc(_post.id).delete();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    await _commentService.addComment(
      postId: _post.id,
      userId: widget.currentUserId,
      username: widget.currentUsername,
      avatar: widget.currentUserAvatar,
      text: text,
      postOwnerId: _post.ownerId,
      senderId: widget.currentUserId,
    );
    _commentController.clear();
    if (!mounted) return;
    setState(() {
      _post.commentCount++;
    });
    NotificationService.showSnackBar(context, 'Comment added!');
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
      await _commentService.deleteComment(_post.id, commentId);
      if (!mounted) return;
      setState(() {
        _post.commentCount--;
      });
      // No notification on comment deletion — only like/comment/follow are supported.
      NotificationService.showSnackBar(context, 'Comment deleted!');
    }
  }

  void _sharePost() {
    // No notification on share — only like/comment/follow are supported.
    NotificationService.showSnackBar(context, 'Shared!');
  }

  void _navigateToEdit() {
    Navigator.pushNamed(
      context,
      '/edit_post',
      arguments: {
        'postId': _post.id,
        'caption': _post.caption,
        'location': _post.location,
        'crossPostMessage': null,
        'isImagePost': false,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_post.username),
        actions: [
          if (_post.ownerId == widget.currentUserId)
            Row(
              children: [
                IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: _navigateToEdit,
                    tooltip: 'Edit post'),
                IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _deletePost,
                    tooltip: 'Delete post'),
              ],
            ),
          IconButton(
            icon: _isLiking
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _post.isLiked ? Colors.red : null, size: 28),
            onPressed: _isLiking ? null : _toggleLike,
            tooltip: _post.isLiked ? 'Unlike' : 'Like',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_post.location != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(_post.location!,
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                Text(_post.caption,
                    style: const TextStyle(fontSize: 18, height: 1.4)),
                const SizedBox(height: 16),
                Text(_post.timeAgo,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const Divider(height: 32),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                          _post.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: _post.isLiked ? Colors.red : null),
                      onPressed: _isLiking ? null : _toggleLike,
                      tooltip: 'Like',
                    ),
                    const SizedBox(width: 4),
                    Text('${_post.likes} likes',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (_post.isLiked)
                      TextButton(
                        onPressed: _isLiking ? null : _toggleLike,
                        child: const Text('Unlike',
                            style: TextStyle(color: Colors.red)),
                      ),
                    IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: _sharePost,
                        tooltip: 'Share'),
                    Row(
                      children: [
                        const Icon(Icons.comment, size: 20, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${_post.commentCount}'),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                const Text('Comments',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                StreamBuilder<List<Comment>>(
                  stream: _commentService.getComments(_post.id),
                  builder: (ctx, snapshot) {
                    if (snapshot.hasError)
                      return Text('Error: ${snapshot.error}');
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final comments = snapshot.data!;
                    if (comments.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child:
                            Text('No comments yet. Be the first to comment!'),
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(comment.text),
                          trailing: comment.userId == widget.currentUserId
                              ? IconButton(
                                  icon: const Icon(Icons.delete,
                                      size: 18, color: Colors.grey),
                                  onPressed: () => _deleteComment(comment.id),
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
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            ),
          ),
        ),
      ),
    );
  }
}
