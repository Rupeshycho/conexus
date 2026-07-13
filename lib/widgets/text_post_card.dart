import 'package:flutter/material.dart';

import '../model/post.dart';

class TextPostCard extends StatelessWidget {
  final Post post;
  final String currentUserId;
  final VoidCallback onLikeTap;
  final VoidCallback onUnlikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;
  final Future<void> Function(String text) onAddComment;

  const TextPostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onLikeTap,
    required this.onUnlikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onEditTap,
    required this.onDeleteTap,
    required this.onAddComment,
  });

  bool get _isOwner => post.ownerId == currentUserId;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage:
                  (post.userAvatar != null && post.userAvatar!.isNotEmpty)
                      ? NetworkImage(post.userAvatar!)
                      : null,
                  child: (post.userAvatar == null || post.userAvatar!.isEmpty)
                      ? Text(post.username.isNotEmpty
                      ? post.username[0].toUpperCase()
                      : '?')
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.username,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (post.location != null)
                        Text(post.location!,
                            style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                if (_isOwner)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEditTap();
                      if (value == 'delete') onDeleteTap();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.caption, style: const TextStyle(fontSize: 16, height: 1.4)),
            const SizedBox(height: 8),
            Text(post.timeAgo,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const Divider(height: 24),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: post.isLiked ? Colors.red : null),
                  onPressed: post.isLiked ? onUnlikeTap : onLikeTap,
                ),
                Text('${post.likes}'),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  onPressed: onCommentTap,
                ),
                Text('${post.commentCount}'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: onShareTap,
                ),
              ],
            ),
            _InlineCommentComposer(onSubmit: onAddComment),
          ],
        ),
      ),
    );
  }
}

class _InlineCommentComposer extends StatefulWidget {
  final Future<void> Function(String text) onSubmit;

  const _InlineCommentComposer({required this.onSubmit});

  @override
  State<_InlineCommentComposer> createState() =>
      _InlineCommentComposerState();
}

class _InlineCommentComposerState extends State<_InlineCommentComposer> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(text);
      _controller.clear();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: !_isSubmitting,
            decoration: const InputDecoration(
              hintText: 'Write a comment...',
              border: OutlineInputBorder(),
              contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _isSubmitting
            ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2))
            : IconButton(
          icon: const Icon(Icons.send),
          color: Colors.blue,
          onPressed: _submit,
        ),
      ],
    );
  }
}
