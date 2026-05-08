import 'package:flutter/material.dart';

void main() => runApp(const ConexusApp());

class ConexusApp extends StatelessWidget {
  const ConexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomeFeed(),
    );
  }
}

class HomeFeed extends StatefulWidget {
  const HomeFeed({super.key});

  @override
  State<HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<HomeFeed> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    FeedPage(),
    Placeholder(), // Explore
    Placeholder(), // Create
    Placeholder(), // Chats
    Placeholder(), // Profile
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.grey.shade200,

        elevation: 1,
        title: Text(

          'Conexus',
          style: TextStyle(
            color: Colors.orange.shade500,
            fontWeight: FontWeight.bold,
          ),
        ),
        // centerTitle: true,
        leading: const CircleAvatar(
          backgroundImage: AssetImage('assets/profile.jpg'),
        ),
        actions: [

          IconButton(
            icon: Icon(Icons.notifications_none, color: Colors.orange.shade200),
            onPressed: () {
              // Open notifications
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Create'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: const [
        PostWidget(
          username: 'martha_',
          location: 'Golden Bay, San Francisco',
          imageUrl: 'assets/post1.jpg',
          caption: 'Golden hours by the shore hit differently...',
          likes: 1284,
          comments: 42,
        ),
        PostWidget(
          username: 'jack_v',
          location: 'Modern Museum',
          imageUrl: 'assets/post2.jpg',
          caption: 'Perspective is everything...',
          likes: 856,
          comments: 12,
        ),
        PostWidget(
          username: 'sara.design',
          location: 'Design Studio',
          imageUrl: 'assets/post3.jpg',
          caption: 'Monday morning essentials...',
          likes: 2410,
          comments: 150,
        ),
      ],
    );
  }
}

class PostWidget extends StatelessWidget {
  final String username, location, imageUrl, caption;
  final int likes, comments;

  const PostWidget({
    super.key,
    required this.username,
    required this.location,
    required this.imageUrl,
    required this.caption,
    required this.likes,
    required this.comments,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const CircleAvatar(
              backgroundImage: AssetImage('assets/profile.jpg'),
            ),
            title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(location),
            trailing: const Icon(Icons.more_vert),
          ),
          Image.asset(imageUrl, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(caption),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                const Icon(Icons.favorite_border),
                const SizedBox(width: 4),
                Text('$likes'),
                const SizedBox(width: 16),
                const Icon(Icons.comment_outlined),
                const SizedBox(width: 4),
                Text('$comments'),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}