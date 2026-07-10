import 'package:flutter/material.dart';
import 'home_feed.dart';
import 'search_screen.dart';
import 'widgets/story_row.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  // TODO: replace with your real logged-in user's uid + photoUrl
  final String currentUserId = 'CURRENT_USER_ID';
  final String currentUserPhotoUrl = '';

  final List<String> screenNames = [
    "Home Feed ",
    "Search Users",
    "Add Posts/Reels",
    "View Reels",
    "Chats",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.orange.shade100,
            child: const Icon(Icons.person, color: Colors.black),
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
            onPressed: () {},
            icon: const Icon(Icons.notifications_none, color: Colors.orange, size: 30),
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
              children: const [
                HomeFeed(),
                SearchScreen(),
                Center(child: Text("Add Posts/Reels")),
                Center(child: Text("View Reels")),
                Center(child: Text("Chats")),
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
              navItem(icon: Icons.video_collection, label: "REELS", index: 3),
              navItem(icon: Icons.chat_bubble_outline, label: "CHATS", index: 4),
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