// lib/view/widgets/story_row.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/suggested_users_viewmodel.dart';

class StoryRow extends StatefulWidget {
  final String currentUserId;
  final String currentUserPhotoUrl;

  const StoryRow({
    super.key,
    required this.currentUserId,
    required this.currentUserPhotoUrl,
  });

  @override
  State<StoryRow> createState() => _StoryRowState();
}

class _StoryRowState extends State<StoryRow> {
  @override
  void initState() {
    super.initState();
    // Load once when the row first mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SuggestedUsersViewModel>().loadSuggestedUsers(widget.currentUserId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SuggestedUsersViewModel>();

    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _storyItem(
            label: 'Your Story',
            photoUrl: widget.currentUserPhotoUrl,
            showAddIcon: true,
          ),
          if (viewModel.isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            ...viewModel.suggestedUsers.map(
                  (user) => _storyItem(label: user.username, photoUrl: user.photoUrl),
            ),
        ],
      ),
    );
  }

  Widget _storyItem({
    required String label,
    required String photoUrl,
    bool showAddIcon = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.orange, Colors.pinkAccent],
                  ),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
                ),
              ),
              if (showAddIcon)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}