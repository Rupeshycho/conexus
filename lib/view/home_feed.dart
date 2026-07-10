import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel/home_feed_viewmodel.dart';
import 'widgets/post_card.dart';
import 'comment_screen.dart';

class HomeFeed extends StatelessWidget {
  const HomeFeed({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeFeedViewModel>();

    if (viewModel.status == FeedStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.status == FeedStatus.error) {
      return Center(child: Text(viewModel.errorMessage ?? 'Something went wrong'));
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
                MaterialPageRoute(builder: (_) => CommentScreen(postId: post.postId)),
              );
            },
            onMenuSelected: (action) {
              final snackText = switch (action) {
                'interested' => 'Marked as interested',
                'not_interested' => 'Marked as not interested',
                'report' => 'Post reported',
                _ => '',
              };
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(snackText)));
              // TODO: call context.read<HomeFeedViewModel>() methods that
              // internally call postRepo.markNotInterested / reportPost
            },
          );
        },
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final FeedPost post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar + Username + Location + Icons + 3 Dot Menu
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: post.avatarUrl != null
                      ? NetworkImage(post.avatarUrl!)
                      : null,
                  child: post.avatarUrl == null
                      ? Text(
                    post.username[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (post.location != null)
                        Text(
                          post.location!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                // Two icons before the three-dot menu
                IconButton(
                  icon: const Icon(Icons.add_box_outlined, size: 22),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.favorite_border, size: 22),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Post Image - LEFT BLANK as requested
          Container(
            width: double.infinity,
            height: 0, // Hidden/blank - no height
            color: Colors.transparent,
          ),

          // Action Buttons: Like, Comment, Share, Save
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.send_outlined),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Likes count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${_formatNumber(post.likes)} likes',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),

          // Caption / Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 14),
                children: [
                  TextSpan(
                    text: '${post.username} ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: post.caption),
                ],
              ),
            ),
          ),

          // Hashtags
          if (post.hashtags != null && post.hashtags!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 4,
                children: post.hashtags!.map((tag) {
                  return Text(
                    tag,
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 14,
                    ),
                  );
                }).toList(),
              ),
            ),

          // Comments button and timestamp
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.commentCount > 0)
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      'View all ${post.commentCount} comments',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  post.timeAgo,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000 && number < 1000000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    return number.toString();
  }
}

class FeedPost {
  final String username;
  final String? location;
  final String? avatarUrl;
  final String? imageUrl; // Made nullable since we're not using images
  final int likes;
  final String caption;
  final List<String>? hashtags;
  final int commentCount;
  final String timeAgo;

  FeedPost({
    required this.username,
    this.location,
    this.avatarUrl,
    this.imageUrl, // Not used but kept for flexibility
    required this.likes,
    required this.caption,
    this.hashtags,
    required this.commentCount,
    required this.timeAgo,
  });
}

// Sample data based on your image
final List<FeedPost> feedPosts = [
  FeedPost(
    username: 'jack_v',
    location: 'Modern Museum',
    avatarUrl: 'https://picsum.photos/id/91/200/200',
    imageUrl: null, // Blank - no image
    likes: 856,
    caption: 'Perspective is everything. Exploring the city\'s hidden gems today.',
    hashtags: null,
    commentCount: 12,
    timeAgo: '5 HOURS AGO',
  ),
  FeedPost(
    username: 'sara.design',
    location: 'Design Studio',
    avatarUrl: 'https://picsum.photos/id/26/200/200',
    imageUrl: null, // Blank - no image
    likes: 2410,
    caption: 'Monday morning essentials. Getting ready for a big week! 🍵',
    hashtags: null,
    commentCount: 156,
    timeAgo: '8 HOURS AGO',
  ),
  FeedPost(
    username: 'martha_',
    location: 'Golden Bay, San Francisco',
    avatarUrl: 'https://picsum.photos/id/64/200/200',
    imageUrl: null,
    likes: 1284,
    caption: 'Golden hours by the shore differently future magic.',
    hashtags: ['#summer', '#vibes', '#goldenhour'],
    commentCount: 42,
    timeAgo: '2 HOURS AGO',
  ),
];