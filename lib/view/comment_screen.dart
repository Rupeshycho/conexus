// lib/view/comment_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../repo/comment_repo.dart';
import '../services/firebase_service.dart';
import 'widgets/comment_tile.dart';

class CommentScreen extends StatefulWidget {
  final String postId;

  const CommentScreen({super.key, required this.postId});

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final _controller = TextEditingController();
  bool _isSending = false;

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final currentUserId = FirebaseService.currentUserId;
    if (currentUserId == null) return;

    setState(() => _isSending = true);

    final commentRepo = context.read<CommentRepo>();
    await commentRepo.addComment(
      postId: widget.postId,
      authorId: currentUserId,
      authorUsername: 'you', // TODO: replace with real profile username
      authorPhotoUrl: '',
      text: text,
    );

    _controller.clear();
    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    final commentRepo = context.read<CommentRepo>();
    final currentUserId = FirebaseService.currentUserId ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: commentRepo.getComments(widget.postId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final comments = snapshot.data!;
                if (comments.isEmpty) {
                  return const Center(
                    child: Text('No comments yet — be the first!'),
                  );
                }
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) => CommentTile(
                    comment: comments[index],
                    currentUserId: currentUserId,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Colors.orange),
                    onPressed: _isSending ? null : _sendComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
