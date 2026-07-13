// lib/widgets/profile_post_grid.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:conexus/model/post_model.dart';
import 'package:conexus/repo/post_repo.dart';
import 'package:conexus/view/post_detail_screen.dart';

class ProfilePostGrid extends StatelessWidget {
  final String userId;
  final PostRepo? postRepo;

  const ProfilePostGrid({super.key, required this.userId, this.postRepo});

  @override
  Widget build(BuildContext context) {
    final repo = postRepo ?? context.read<PostRepo>();
    final viewerId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<List<PostModel>>(
      stream: repo.getUserPosts(userId, viewerId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load posts: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final posts = snapshot.data!;
        if (posts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No posts yet')),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: posts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final post = posts[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(postId: post.postId),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: post.mediaUrl != null && post.mediaUrl!.isNotEmpty
                    ? Image.network(
                  post.mediaUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholderTile(),
                )
                    : _textTile(post.caption),
              ),
            );
          },
        );
      },
    );
  }

  Widget _placeholderTile() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade200, Colors.deepOrange.shade300],
        ),
      ),
      child: const Icon(Icons.broken_image, color: Colors.white, size: 35),
    );
  }

  Widget _textTile(String caption) {
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade200, Colors.deepOrange.shade300],
        ),
      ),
      child: Text(
        caption.isEmpty ? '(no caption)' : caption,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}