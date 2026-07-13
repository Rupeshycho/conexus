// lib/view/home_screen.dart
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:conexus/widgets/story_row.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'create_image_post.dart';
import 'create_text_post.dart';
import 'home_feed.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'send_message.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  final List<String> screenNames = [
    "Home Feed ",
    "Search Users",
    "Add Posts/Reels",
    "Chats",
  ];

  // Shows a picker so the person can choose Image or Text post, then
  // pushes the matching create screen.
  void _openCreatePostPicker({
    required String currentUserId,
    required String currentUsername,
    required String? currentUserAvatar,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.add_photo_alternate),
              title: const Text('Image Post'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateImagePostScreen(
                      currentUserId: currentUserId,
                      currentUsername: currentUsername,
                      currentUserAvatar: currentUserAvatar,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Text Post'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateTextPostScreen(
                      currentUserId: currentUserId,
                      currentUsername: currentUsername,
                      currentUserAvatar: currentUserAvatar,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Real signed-in user, no more placeholder TODOs.
    final userViewModel = context.watch<UserViewModel>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    // Matches the getter EditProfile/ProfileScreen use (currentUser),
    // instead of the old `.user` getter that likely doesn't exist.
    final currentUserPhotoUrl = userViewModel.currentUser?.profileImage ?? '';
    // Adjust this getter name if your UserViewModel exposes it differently
    // (e.g. displayName, name) — used when publishing a new post.
    final currentUsername =
        userViewModel.currentUser?.username ??
        FirebaseAuth.instance.currentUser?.displayName ??
        'User';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            child: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              backgroundImage: currentUserPhotoUrl.isNotEmpty
                  ? NetworkImage(currentUserPhotoUrl)
                  : null,
              child: currentUserPhotoUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.black)
                  : null,
            ),
          ),
        ),
        title: const Text(
          "Conexus",
          style: TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(
              Icons.settings_outlined,
              color: Colors.orange,
              size: 28,
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              );
            },
            icon: const Icon(
              Icons.notifications_none,
              color: Colors.orange,
              size: 30,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Story row: only makes sense on the Home tab ──
          if (selectedIndex == 0)
            StoryRow(
              currentUserId: currentUserId,
              currentUserPhotoUrl: currentUserPhotoUrl,
            ),

          Expanded(
            child: IndexedStack(
              index: selectedIndex,
              children: [
                const HomeFeed(),
                const SearchScreen(),
                // CREATE tab: opens the Image/Text picker as soon as it's
                // shown, and falls back to a tappable prompt otherwise.
                _CreatePostTab(
                  onOpenPicker: () => _openCreatePostPicker(
                    currentUserId: currentUserId,
                    currentUsername: currentUsername,
                    currentUserAvatar: currentUserPhotoUrl.isEmpty
                        ? null
                        : currentUserPhotoUrl,
                  ),
                ),
                const MessageFrame(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 2,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              navItem(icon: Icons.home, label: "HOME", index: 0),
              navItem(icon: Icons.search, label: "SEARCH", index: 1),
              navItem(icon: Icons.add_box_outlined, label: "CREATE", index: 2),
              navItem(
                icon: Icons.chat_bubble_outline,
                label: "CHATS",
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget navItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => selectedIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? Colors.orange : Colors.grey),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.orange : Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Content shown for the CREATE tab: a simple prompt that opens the
/// post-type picker, either automatically on first appearance or via tap.
class _CreatePostTab extends StatefulWidget {
  final VoidCallback onOpenPicker;

  const _CreatePostTab({required this.onOpenPicker});

  @override
  State<_CreatePostTab> createState() => _CreatePostTabState();
}

class _CreatePostTabState extends State<_CreatePostTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onOpenPicker();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: widget.onOpenPicker,
        icon: const Icon(Icons.add_circle_outline, size: 32),
        label: const Text('Create a post', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
