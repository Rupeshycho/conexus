import 'package:flutter/material.dart';
import '../model/comment.dart';
import '../model/post.dart';
import '../repo/comment_service.dart';

class TextPostCard extends StatelessWidget {
  final Post post;
  final String currentUserId;
  final VoidCallback onLikeTap;
  final VoidCallback onUnlikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;
  final VoidCallback onShareTap;
  final Function(String) onAddComment;

  const TextPostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onLikeTap,
    required this.onUnlikeTap,
    required this.onCommentTap,
    required this.onEditTap,
    required this.onDeleteTap,
    required this.onShareTap,
    required this.onAddComment,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController commentController = TextEditingController();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: (post.userAvatar != null && post.userAvatar!.isNotEmpty)
                      ? NetworkImage(post.userAvatar!)
                      : null,
                  child: (post.userAvatar == null || post.userAvatar!.isEmpty)
                      ? Text(post.username[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.username,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (post.location != null)
                        Text(
                          post.location!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (post.ownerId == currentUserId)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'edit') onEditTap();
                      if (value == 'delete') onDeleteTap();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(post.caption, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              post.timeAgo,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const Divider(),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked ? Colors.red : null,
                  ),
                  onPressed: onLikeTap,
                ),
                if (post.isLiked)
                  TextButton(
                    onPressed: onUnlikeTap,
                    child: const Text(
                      'Unlike',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(width: 4),
                Text('${post.likes} likes'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: onShareTap,
                  tooltip: 'Share',
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: onCommentTap,
                ),
                const SizedBox(width: 4),
                Text('${post.commentCount}'),
              ],
            ),
            StreamBuilder<List<Comment>>(
              stream: CommentService().getComments(post.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final comments = snapshot.data!;
                if (comments.isEmpty) return const SizedBox.shrink();
                final displayComments = comments.reversed.take(2).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: displayComments.map((comment) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            comment.username.isNotEmpty
                                ? comment.username[0].toUpperCase()
                                : '?', // ✅ safe fallback
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              comment.text,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentController,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty) {
                        onAddComment(text.trim());
                        commentController.clear();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, size: 20),
                  onPressed: () {
                    final text = commentController.text.trim();
                    if (text.isNotEmpty) {
                      onAddComment(text);
                      commentController.clear();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}