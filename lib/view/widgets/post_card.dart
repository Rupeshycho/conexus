// lib/view/widgets/post_card.dart
import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import 'video_post_player.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onCommentTap;
  final void Function(String action)? onMenuSelected; // "interested" / "not_interested" / "report"

  const PostCard({
    super.key,
    required this.post,
    this.onCommentTap,
    this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: profile picture left, "..." menu right ──
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: post.authorPhotoUrl.isNotEmpty
                      ? NetworkImage(post.authorPhotoUrl)
                      : null,
                  child: post.authorPhotoUrl.isEmpty ? const Icon(Icons.person) : null,
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
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'interested', child: Text('Interested')),
                    PopupMenuItem(value: 'not_interested', child: Text('Not interested')),
                    PopupMenuItem(value: 'report', child: Text('Report')),
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
                  errorBuilder: (context, error, stack) =>
                  const SizedBox(height: 200, child: Icon(Icons.broken_image)),
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
                IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
                Text('${post.likeCount}'),
                const SizedBox(width: 12),
                IconButton(icon: const Icon(Icons.comment_outlined), onPressed: onCommentTap),
                Text('${post.commentCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}