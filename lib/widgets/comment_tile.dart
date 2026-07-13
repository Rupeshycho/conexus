// lib/view/widgets/comment_tile.dart
import 'package:conexus/model/comment_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../repo/comment_repo.dart';

class CommentTile extends StatelessWidget {
  final CommentModel comment;
  final String currentUserId;
  final String currentUsername;
  final String currentUserPhotoUrl;

  const CommentTile({
    super.key,
    required this.comment,
    required this.currentUserId,
    required this.currentUsername,
    required this.currentUserPhotoUrl,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This can\'t be undone.'),
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

    if (confirmed == true && context.mounted) {
      await context.read<CommentRepo>().deleteComment(
        comment.commentId,
        currentUserId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = comment.isLikedBy(currentUserId);
    final isOwnComment = comment.authorId == currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: comment.authorPhotoUrl.isNotEmpty
                ? NetworkImage(comment.authorPhotoUrl)
                : null,
            child: comment.authorPhotoUrl.isEmpty
                ? const Icon(Icons.person, size: 18)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.authorUsername,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(comment.text, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      timeago.format(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (comment.likeCount > 0)
                      Text(
                        '${comment.likeCount} likes',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    if (isOwnComment) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _confirmDelete(context),
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: isLiked ? Colors.red : Colors.grey,
            ),
            onPressed: () {
              context.read<CommentRepo>().toggleLikeComment(
                commentId: comment.commentId,
                userId: currentUserId,
                username: currentUsername,
                userPhotoUrl: currentUserPhotoUrl,
              );
            },
          ),
        ],
      ),
    );
  }
}
