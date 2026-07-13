// lib/view/widgets/story_row.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/user_model.dart';
import '../../viewmodel/user_view_model.dart';

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
  List<UserModel> _followingUsers = [];
  bool _loading = false;
  List<String> _loadedForIds = [];

  Future<void> _loadFollowingUsers(List<String> followingIds) async {
    if (followingIds.isEmpty) {
      setState(() {
        _followingUsers = [];
        _loadedForIds = [];
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final userViewModel = context.read<UserViewModel>();
      final users = await Future.wait(
        followingIds.map((id) => userViewModel.getUser(id)),
      );
      if (!mounted) return;
      setState(() {
        _followingUsers = users;
        _loadedForIds = followingIds;
      });
    } catch (e) {
      debugPrint('❌ Failed to load following users for story row: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userViewModel = context.watch<UserViewModel>();
    final followingIds = userViewModel.user?.following ?? [];

    // Re-fetch only when the following list actually changes.
    if (!_loading && !_listEquals(followingIds, _loadedForIds)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadFollowingUsers(followingIds);
      });
    }

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
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            ..._followingUsers.map(
              (user) =>
                  _storyItem(label: user.name, photoUrl: user.profileImage),
            ),
        ],
      ),
    );
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
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
