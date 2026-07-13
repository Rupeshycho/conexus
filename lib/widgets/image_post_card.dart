import 'package:flutter/material.dart';

import '../model/comment.dart';
import '../repo/comment_service.dart';

class ImagePostCard extends StatefulWidget {
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
  final bool isBookmarked;
  final VoidCallback onLikeTap;
  final VoidCallback onUnlikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;
  final VoidCallback? onBookmarkTap;
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
    this.isBookmarked = false,
    required this.onLikeTap,
    required this.onUnlikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onEditTap,
    required this.onDeleteTap,
    this.onBookmarkTap,
    required this.postId,
    required this.currentUserId,
    required this.onAddComment,
  });

  @override
  State<ImagePostCard> createState() => _ImagePostCardState();
}

class _ImagePostCardState extends State<ImagePostCard>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _commentController = TextEditingController();
  late final AnimationController _heartAnimController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _heartScale = CurvedAnimation(
    parent: _heartAnimController,
    curve: Curves.elasticOut,
  );

  @override
  void dispose() {
    _commentController.dispose();
    _heartAnimController.dispose();
    super.dispose();
  }

  String get _avatarInitial =>
      widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?';

  String get _timeAgo {
    final difference = DateTime.now().difference(widget.timestamp);
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

  void _handleDoubleTapLike() {
    if (!widget.isLiked) widget.onLikeTap();
    _heartAnimController.forward(from: 0);
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    widget.onAddComment(text);
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildImage(),
          _buildActionRow(),
          _buildLikesCount(),
          _buildCaption(),
          _buildCommentsSection(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: widget.userAvatar.isNotEmpty
                ? NetworkImage(widget.userAvatar)
                : null,
            radius: 20,
            child: widget.userAvatar.isEmpty ? Text(_avatarInitial) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.username.isNotEmpty ? widget.username : 'Unknown user',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (widget.location != null && widget.location!.isNotEmpty)
                  Text(
                    widget.location!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'edit') widget.onEditTap();
              if (value == 'delete') widget.onDeleteTap();
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
    );
  }

  Widget _buildImage() {
    return GestureDetector(
      onDoubleTap: _handleDoubleTapLike,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.network(
              widget.imageUrl,
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 300,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                height: 300,
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                ),
              ),
            ),
            ScaleTransition(
              scale: _heartScale,
              child: const Icon(Icons.favorite, color: Colors.white, size: 90),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              widget.isLiked ? Icons.favorite : Icons.favorite_border,
              color: widget.isLiked ? Colors.red : null,
            ),
            tooltip: widget.isLiked ? 'Unlike' : 'Like',
            onPressed: widget.isLiked ? widget.onUnlikeTap : widget.onLikeTap,
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Comment',
            onPressed: widget.onCommentTap,
          ),
          IconButton(
            icon: const Icon(Icons.send_outlined),
            tooltip: 'Share',
            onPressed: widget.onShareTap,
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            ),
            tooltip: widget.isBookmarked ? 'Remove bookmark' : 'Save',
            onPressed: widget.onBookmarkTap,
          ),
        ],
      ),
    );
  }

  Widget _buildLikesCount() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        '${widget.likes} ${widget.likes == 1 ? 'like' : 'likes'}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildCaption() {
    if (widget.caption.isEmpty && widget.hashtags.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(
              text: '${widget.username} ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: widget.caption),
            if (widget.hashtags.isNotEmpty) ...[
              const TextSpan(text: ' '),
              ...widget.hashtags.map(
                (tag) => TextSpan(
                  text: '#$tag ',
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<List<Comment>>(
            stream: CommentService().getComments(widget.postId),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const SizedBox.shrink();
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 20,
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment.username.isNotEmpty
                              ? comment.username[0].toUpperCase()
                              : '?',
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
          if (widget.commentCount > 0)
            GestureDetector(
              onTap: widget.onCommentTap,
              child: Text(
                'View all ${widget.commentCount} comments',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitComment(),
                  decoration: const InputDecoration(
                    hintText: 'Write a comment...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, size: 20),
                tooltip: 'Post comment',
                onPressed: _submitComment,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _timeAgo,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
