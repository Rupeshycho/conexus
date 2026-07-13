// lib/view/home_feed.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conexus/repo/post_repo.dart';
import 'package:conexus/services/firebase_service.dart';
import 'package:conexus/viewmodel/home_feed_viewmodel.dart';
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:conexus/widgets/offline_banner.dart';
import 'package:conexus/widgets/post_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'comment_screen.dart';

class HomeFeed extends StatefulWidget {
  const HomeFeed({super.key});

  @override
  State<HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<HomeFeed> {
  String _currentUsername = '';
  String _currentUserPhotoUrl = '';
  StreamSubscription<DocumentSnapshot>? _userSub;

  @override
  void initState() {
    super.initState();
    _listenToCurrentUserProfile();
  }

  void _listenToCurrentUserProfile() {
    final uid = FirebaseService.currentUserId;
    if (uid == null) return;

    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
          final data = doc.data();
          if (!mounted) return;
          setState(() {
            _currentUsername = data?['username'] ?? 'User';
            _currentUserPhotoUrl = data?['profileImage'] ?? '';
          });
        });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _confirmDeletePost(String postId, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text(
          'This will also delete its comments. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  Future<void> _editPostCaption(
    String postId,
    String userId,
    String currentCaption,
  ) async {
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeFeedViewModel>();
    final currentUserId = FirebaseService.currentUserId ?? '';

    // Hide posts from anyone the current user has blocked.
    final blockedIds = context.watch<UserViewModel>().user?.blockedUsers ?? [];

    Widget body;

    if (viewModel.status == FeedStatus.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (viewModel.status == FeedStatus.error) {
      body = Center(
        child: Text(viewModel.errorMessage ?? 'Something went wrong'),
      );
    } else {
      final visiblePosts = blockedIds.isEmpty
          ? viewModel.posts
          : viewModel.posts
                .where((post) => !blockedIds.contains(post.authorId))
                .toList();

      if (visiblePosts.isEmpty) {
        body = const Center(child: Text('No posts yet'));
      } else {
        body = RefreshIndicator(
          onRefresh: () => context.read<HomeFeedViewModel>().refreshFeed(),
          child: ListView.builder(
            itemCount: visiblePosts.length,
            itemBuilder: (context, index) {
              final post = visiblePosts[index];
              return PostCard(
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
                      _editPostCaption(
                        post.postId,
                        currentUserId,
                        post.caption,
                      );
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
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(snackText)));
                      break;
                  }
                },
              );
            },
          ),
        );
      }
    }

    return OfflineBanner(child: body);
  }
}
