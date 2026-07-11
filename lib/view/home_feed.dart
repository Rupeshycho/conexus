// lib/view/home_feed.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodel/home_feed_viewmodel.dart';
import 'comment_screen.dart';
import 'widgets/post_card.dart';

class HomeFeed extends StatelessWidget {
  const HomeFeed({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeFeedViewModel>();

    if (viewModel.status == FeedStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.status == FeedStatus.error) {
      return Center(
        child: Text(viewModel.errorMessage ?? 'Something went wrong'),
      );
    }
    if (viewModel.posts.isEmpty) {
      return const Center(child: Text('No posts yet'));
    }

    return RefreshIndicator(
      onRefresh: () => context.read<HomeFeedViewModel>().refreshFeed(),
      child: ListView.builder(
        itemCount: viewModel.posts.length,
        itemBuilder: (context, index) {
          final post = viewModel.posts[index];
          return PostCard(
            post: post,
            onCommentTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CommentScreen(postId: post.postId),
                ),
              );
            },
            onMenuSelected: (action) {
              final snackText = switch (action) {
                'interested' => 'Marked as interested',
                'not_interested' => 'Marked as not interested',
                'report' => 'Post reported',
                _ => '',
              };
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(snackText)));
              // TODO: call context.read<HomeFeedViewModel>() methods that
              // internally call postRepo.markNotInterested / reportPost
            },
          );
        },
      ),
    );
  }
}
