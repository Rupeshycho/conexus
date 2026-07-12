import 'package:flutter/material.dart';
import '../model/comment.dart';
import '../repo/comment_service.dart';

class ImagePostCard extends StatelessWidget {
  final String userAvatar;
  final String username;
  final String? location;
  final String imageUrl;
  final int likes;
  final String caption;
  final List<String> hashtags;
  final int commentCount;
  final DateTime timestamp;
  final bool isLiked;
  final VoidCallback onLikeTap;
  final VoidCallback onUnlikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;
  final String postId;
  final String currentUserId;
  final Function(String) onAddComment;

  const ImagePostCard({
    super.key,
    required this.userAvatar,
    required this.username,
    this.location,
    required this.imageUrl,
    required this.likes,
    required this.caption,
    required this.hashtags,
    required this.commentCount,
    required this.timestamp,
    required this.isLiked,
    required this.onLikeTap,
    required this.onUnlikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onEditTap,
    required this.onDeleteTap,
    required this.postId,
    required this.currentUserId,
    required this.onAddComment,
  });

  String _timeAgo() {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 7) {
      return '${difference.inDays} days ago';
    }
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    }
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController commentController = TextEditingController();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
                  child: userAvatar.isEmpty ? Text(username[0].toUpperCase()) : null,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (location != null)
                        Text(
                          location!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') onEditTap();
                    if (value == 'delete') onDeleteTap();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : null,
                  ),
                  onPressed: onLikeTap,
                ),
                if (isLiked)
                  TextButton(
                    onPressed: onUnlikeTap,
                    child: const Text(
                      'Unlike',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: onCommentTap,
                ),
                IconButton(
                  icon: const Icon(Icons.send_outlined),
                  onPressed: onShareTap,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          // Likes
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$likes likes',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          // Caption
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$username ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: caption),
                  if (hashtags.isNotEmpty) ...[
                    const TextSpan(text: ' '),
                    ...hashtags.map(
                          (tag) => TextSpan(
                        text: '#$tag ',
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Comments section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<List<Comment>>(
                  stream: CommentService().getComments(postId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const SizedBox.shrink();
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 20,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
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
                if (commentCount > 0)
                  GestureDetector(
                    onTap: onCommentTap,
                    child: Text(
                      'View all $commentCount comments',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
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
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _timeAgo(),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}