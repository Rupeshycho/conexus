// lib/view/comment_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:conexus/repo/comment_repo.dart';
import 'package:conexus/services/firebase_service.dart';
import 'package:conexus/widgets/comment_tile.dart';

class CommentScreen extends StatefulWidget {
  final String postId;

  const CommentScreen({super.key, required this.postId});

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final _controller = TextEditingController();
  bool _isSending = false;

  String _currentUsername = '';
  String _currentUserPhotoUrl = '';
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
  }

  Future<void> _loadCurrentUserProfile() async {
    final uid = FirebaseService.currentUserId;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (!mounted) return;
    setState(() {
      _currentUsername = data?['username'] ?? 'User';
      _currentUserPhotoUrl = data?['photoUrl'] ?? '';
      _profileLoaded = true;
    });
  }

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
      authorUsername: _currentUsername.isNotEmpty ? _currentUsername : 'User',
      authorPhotoUrl: _currentUserPhotoUrl,
      text: text,
    );

    _controller.clear();
    if (mounted) setState(() => _isSending = false);
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
                    currentUsername: _currentUsername,
                    currentUserPhotoUrl: _currentUserPhotoUrl,
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
                    onPressed: (_isSending || !_profileLoaded) ? null : _sendComment,
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