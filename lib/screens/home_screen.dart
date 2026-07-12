import 'package:flutter/material.dart';

import 'image_feed_screen.dart';
import 'text_feed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final String currentUserId = 'user123';
  final String currentUsername = 'JohnDoe';
  final String? currentUserAvatar = null;

  final List<Widget> _pages = [
    const ImageFeedScreen(),
    const TextFeedScreen(),
    const Center(child: Text('Create Post (choose type)')), // placeholder
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      _showCreateDialog();
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Create Image Post'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/create_image',
                  arguments: {
                    'currentUserId': currentUserId,
                    'currentUsername': currentUsername,
                    'currentUserAvatar': currentUserAvatar,
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Create Text Post'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/create_text',
                  arguments: {
                    'currentUserId': currentUserId,
                    'currentUsername': currentUsername,
                    'currentUserAvatar': currentUserAvatar,
                  },
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conexus'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.image), label: 'Images'),
          BottomNavigationBarItem(
            icon: Icon(Icons.text_fields),
            label: 'Texts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            label: 'Create',
          ),
        ],
      ),
    );
  }
}
