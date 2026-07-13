// lib/view/post_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:conexus/model/post_model.dart';
import 'package:conexus/repo/post_repo.dart';
import 'package:conexus/services/firebase_service.dart';
import 'package:conexus/widgets/post_card.dart';
import 'comment_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  String _currentUsername = '';
  String _currentUserPhotoUrl = '';

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
    });
  }

  Future<void> _confirmDeletePost(String postId, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This will also delete its comments. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<PostRepo>().deletePost(postId, userId);
      if (mounted) Navigator.pop(context); // leave detail view, post is gone
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _editPostCaption(String postId, String userId, String currentCaption) async {
    final controller = TextEditingController(text: currentCaption);

    final newCaption = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit post'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          maxLength: 500,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Caption'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newCaption == null || newCaption.isEmpty || !mounted) return;

    try {
      await context.read<PostRepo>().editPost(
        postId: postId,
        userId: userId,
        caption: newCaption,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseService.currentUserId ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: StreamBuilder<PostModel?>(
        stream: context.read<PostRepo>().getPostById(widget.postId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final post = snapshot.data;
          if (post == null) {
            return const Center(child: Text('This post was deleted'));
          }

          return SingleChildScrollView(
            child: PostCard(
              post: post,
              currentUserId: currentUserId,
              onLikeTap: () {
                context.read<PostRepo>().toggleLikePost(
                  postId: post.postId,
                  userId: currentUserId,
                  username: _currentUsername,
                  userPhotoUrl: _currentUserPhotoUrl,
                );
              },
              onCommentTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommentScreen(postId: post.postId),
                  ),
                );
              },
              onMenuSelected: (action) {
                switch (action) {
                  case 'edit':
                    _editPostCaption(post.postId, currentUserId, post.caption);
                    break;
                  case 'delete':
                    _confirmDeletePost(post.postId, currentUserId);
                    break;
                  case 'interested':
                  case 'not_interested':
                  case 'report':
                    final snackText = switch (action) {
                      'interested' => 'Marked as interested',
                      'not_interested' => 'Marked as not interested',
                      'report' => 'Post reported',
                      _ => '',
                    };
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(snackText)));
                    break;
                }
              },
            ),
          );
        },
      ),
    );
  }
}