// lib/view/widgets/post_card.dart
import 'package:flutter/material.dart';

import '../../model/post_model.dart';
import 'video_post_player.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final String currentUserId;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;
  final void Function(String action)? onMenuSelected;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    this.onLikeTap,
    this.onCommentTap,
    this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isLiked = post.isLikedBy(currentUserId);
    final isOwnPost = post.authorId == currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: post.authorPhotoUrl.isNotEmpty
                      ? NetworkImage(post.authorPhotoUrl)
                      : null,
                  child: post.authorPhotoUrl.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    post.authorUsername,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) => onMenuSelected?.call(value),
                  itemBuilder: (context) => [
                    if (isOwnPost) ...[
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ] else ...[
                      const PopupMenuItem(
                        value: 'interested',
                        child: Text('Interested'),
                      ),
                      const PopupMenuItem(
                        value: 'not_interested',
                        child: Text('Not interested'),
                      ),
                      const PopupMenuItem(
                        value: 'report',
                        child: Text('Report'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (post.caption.isNotEmpty) Text(post.caption),
            if (post.type == PostType.image && post.mediaUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.mediaUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stack) => const SizedBox(
                    height: 200,
                    child: Icon(Icons.broken_image),
                  ),
                ),
              ),
            ],
            if (post.type == PostType.video && post.mediaUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: VideoPostPlayer(videoUrl: post.mediaUrl!),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : null,
                  ),
                  onPressed: onLikeTap,
                ),
                Text('${post.likeCount}'),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  onPressed: onCommentTap,
                ),
                Text('${post.commentCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
