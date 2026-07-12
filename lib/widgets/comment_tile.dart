// lib/view/widgets/comment_tile.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/comment_model.dart';
import '../../repo/comment_repo.dart';

class CommentTile extends StatelessWidget {
  final CommentModel comment;
  final String currentUserId;

  const CommentTile({
    super.key,
    required this.comment,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isLiked = comment.isLikedBy(currentUserId);

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
              // Fixed: only commentId + userId now — no postId
              context.read<CommentRepo>().toggleLikeComment(
                comment.commentId,
                currentUserId,
              );
            },
          ),
        ],
      ),
    );
  }
}
