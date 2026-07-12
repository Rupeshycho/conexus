import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../model/comment.dart';
import '../repo/comment_service.dart';
import '../repo/notification_service.dart';

class ViewImagePost extends StatefulWidget {
  const ViewImagePost({super.key});

  @override
  State<ViewImagePost> createState() => _ViewImagePostState();
}

class _ViewImagePostState extends State<ViewImagePost> {
  late String postId;
  late String currentUserId;
  final CommentService _commentService = CommentService();
  final TextEditingController _commentController = TextEditingController();
  bool _isLiking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
    ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    postId = args['postId'];
    currentUserId = args['currentUserId'];
  }

  Future<void> _toggleLike(DocumentSnapshot postDoc) async {
    if (_isLiking) return;
    setState(() => _isLiking = true);
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final likes = List<String>.from(postDoc.get('likes') ?? []);
    final ownerId = postDoc.get('ownerId') ?? '';

    if (likes.contains(currentUserId)) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([currentUserId]),
      });
      if (mounted) NotificationService.showSnackBar(context, 'Unliked!');
      await NotificationService.createNotification(
        receiverId: ownerId,
        senderId: currentUserId,
        type: 'unlike',
        postId: postId,
        message: 'Someone unliked your post',
      );
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([currentUserId]),
      });
      if (mounted) NotificationService.showSnackBar(context, 'Liked!');
      await NotificationService.createNotification(
        receiverId: ownerId,
        senderId: currentUserId,
        type: 'like',
        postId: postId,
        message: 'Someone liked your post',
      );
    }
    setState(() => _isLiking = false);
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
      message: 'Someone deleted a post',
    );

    if (mounted) Navigator.pop(context);
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final postDoc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .get();
    final ownerId = postDoc.data()?['ownerId'] ?? '';
    await _commentService.addComment(
      postId: postId,
      userId: currentUserId,
      username: 'CurrentUser',
      avatar: null,
      text: text,
      postOwnerId: ownerId,
      senderId: currentUserId,
    );
    _commentController.clear();
    if (mounted) NotificationService.showSnackBar(context, 'Comment added!');
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
      await _commentService.deleteComment(postId, commentId);
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      final ownerId = postDoc.data()?['ownerId'] ?? '';
      await NotificationService.createNotification(
        receiverId: ownerId,
        senderId: currentUserId,
        type: 'delete_comment',
        postId: postId,
        message: 'Someone deleted a comment on your post',
      );
      if (mounted) NotificationService.showSnackBar(context, 'Comment deleted!');
    }
  }

  void _sharePost(DocumentSnapshot snapshot) async {
    final ownerId = snapshot.get('ownerId') ?? '';
    await NotificationService.createNotification(
      receiverId: ownerId,
      senderId: currentUserId,
      type: 'share',
      postId: postId,
      message: 'Someone shared your post',
    );
    if (mounted) NotificationService.showSnackBar(context, 'Shared!');
  }

  void _navigateToEdit(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    Navigator.pushNamed(
      context,
      '/edit_post',
      arguments: {
        'postId': postId,
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
                .doc(postId)
                .snapshots(),
            builder: (ctx, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final ownerId = snapshot.data!.get('ownerId') ?? '';
              if (ownerId != currentUserId) return const SizedBox.shrink();
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
                  .doc(postId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final caption = data['caption'] ?? '';
                final imageUrl = data['imageUrl'] ?? '';
                final likesList = List<String>.from(data['likes'] ?? []);
                final isLiked = likesList.contains(currentUserId);
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
                            size: 30,
                          ),
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
                            child: const Text(
                              'Unlike',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: () => _sharePost(snapshot.data!),
                          tooltip: 'Share',
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<Comment>>(
                      stream: _commentService.getComments(postId),
                      builder: (ctx, commentSnapshot) {
                        if (commentSnapshot.hasError) {
                          return Text('Error: ${commentSnapshot.error}');
                        }
                        if (!commentSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final comments = commentSnapshot.data!;
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
                                child: Text(
                                  comment.username.isNotEmpty
                                      ? comment.username[0].toUpperCase()
                                      : '?', // ✅ safe fallback
                                ),
                              ),
                              title: Text(
                                comment.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(comment.text),
                              trailing: comment.userId == currentUserId
                                  ? IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: Colors.grey,
                                ),
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