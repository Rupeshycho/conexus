import 'package:flutter/material.dart';

import 'post.dart';

class ViewTextPost extends StatelessWidget {
  final Post post;
  final VoidCallback onLikePressed;

  const ViewTextPost({
    super.key,
    required this.post,
    required this.onLikePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(post.username),
        actions: [
          IconButton(
            icon: Icon(
              post.isLiked ? Icons.favorite : Icons.favorite_border,
              color: post.isLiked ? Colors.red : null,
              size: 28,
            ),
            onPressed: post.isLiked ? null : onLikePressed,
            tooltip: 'Like',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.location != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      post.location!,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            Text(
              post.caption,
              style: const TextStyle(fontSize: 18, height: 1.4),
            ),
            const SizedBox(height: 16),
            Text(
              post.timeAgo,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const Divider(height: 32),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked ? Colors.red : null,
                  ),
                  onPressed: onLikePressed,
                  tooltip: 'Like',
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.likes} likes',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.comment, size: 20, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${post.commentCount}'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
