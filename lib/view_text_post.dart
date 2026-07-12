import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'comment.dart';
import 'comment_service.dart';
import 'edit_post_screen.dart';
import 'post.dart';

class ViewTextPost extends StatefulWidget {
  final Post post;
  final String currentUserId;

  const ViewTextPost({
    super.key,
    required this.post,
    required this.currentUserId,
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

  // ---------- FEATURE 1: LIKE / UNLIKE toggle ----------
  Future<void> _toggleLike() async {
    if (_isLiking) return;
    setState(() => _isLiking = true);

    try {
      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(_post.id);
      if (_post.isLiked) {
        // UNLIKE: remove current user from likes array
        await postRef.update({
          'likes': FieldValue.arrayRemove([widget.currentUserId]),
        });
        setState(() {
          _post.isLiked = false;
          _post.likes--;
        });
      } else {
        // LIKE: add current user to likes array
        await postRef.update({
          'likes': FieldValue.arrayUnion([widget.currentUserId]),
        });
        setState(() {
          _post.isLiked = true;
          _post.likes++;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update like: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  // ---------- FEATURE 2: DELETE post (with confirmation) ----------
  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
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
    if (confirm != true) return;

    await FirebaseFirestore.instance.collection('posts').doc(_post.id).delete();
    if (mounted) Navigator.pop(context);
  }

  // ---------- FEATURE 3: ADD comment ----------
  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    await _commentService.addComment(
      _post.id,
      widget.currentUserId,
      'CurrentUser',
      null,
      text,
    );
    _commentController.clear();
    setState(() {
      _post.commentCount++;
    });
  }

  // ---------- FEATURE 4: DELETE comment (with confirmation) ----------
  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Delete this comment?'),
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
      await _commentService.deleteComment(_post.id, commentId);
      setState(() {
        _post.commentCount--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_post.username),
        actions: [
          // ---------- FEATURE 5: EDIT post (only for owner) ----------
          if (_post.ownerId == widget.currentUserId)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditPostScreen(
                          postId: _post.id,
                          initialCaption: _post.caption,
                          initialLocation: _post.location,
                          initialCrossPostMessage: null,
                          isImagePost: false,
                        ),
                      ),
                    ).then((_) {});
                  },
                  tooltip: 'Edit post',
                ),
                // ---------- FEATURE 6: DELETE button (only for owner) ----------
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _deletePost,
                  tooltip: 'Delete post',
                ),
              ],
            ),
          // ---------- FEATURE 7: LIKE/UNLIKE button (for everyone) ----------
          IconButton(
            icon: _isLiking
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _post.isLiked ? Colors.red : null,
                    size: 28,
                  ),
            onPressed: _isLiking ? null : _toggleLike,
            tooltip: _post.isLiked ? 'Unlike' : 'Like',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------- Location (if present) ----------
                  if (_post.location != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _post.location!,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  // ---------- Post caption ----------
                  Text(
                    _post.caption,
                    style: const TextStyle(fontSize: 18, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  // ---------- Timestamp ----------
                  Text(
                    _post.timeAgo,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Divider(height: 32),
                  // ---------- Like count & comment count ----------
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _post.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: _post.isLiked ? Colors.red : null,
                        ),
                        onPressed: _isLiking ? null : _toggleLike,
                        tooltip: 'Like',
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_post.likes} likes',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.comment,
                            size: 20,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text('${_post.commentCount}'),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  // ---------- Comment list ----------
                  const Text(
                    'Comments',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
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
                          child: Text(
                            'No comments yet. Be the first to comment!',
                          ),
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
                              child: Text(comment.username[0].toUpperCase()),
                            ),
                            title: Text(
                              comment.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(comment.text),
                            // ---------- Delete comment (only for own comments) ----------
                            trailing: comment.userId == widget.currentUserId
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () => _deleteComment(comment.id),
                                  )
                                : null,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // ---------- Add comment text field ----------
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addComment,
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
