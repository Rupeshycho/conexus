import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'other_profile_screen.dart';

class FollowingList extends StatefulWidget {
  final List<String> following;

  const FollowingList({super.key, required this.following});

  @override
  State<FollowingList> createState() => _FollowingListState();
}

class _FollowingListState extends State<FollowingList> {
  Map<String, dynamic> userData = {}; // stores the full UserModel per uid

  @override
  void initState() {
    super.initState();
    _loadUserNames();
  }

  Future<void> _loadUserNames() async {
    final userVM = context.read<UserViewModel>();
    Map<String, dynamic> data = {};

    for (String uid in widget.following) {
      try {
        final user = await userVM.getUser(uid);
        data[uid] = user;
      } catch (e) {
        data[uid] = null;
      }
    }

    setState(() {
      userData = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Following",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepOrange,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: widget.following.isEmpty
          ? const Center(
        child: Text(
          "Not Following Anyone",
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        itemCount: widget.following.length,
        itemBuilder: (context, index) {
          final uid = widget.following[index];
          final user = userData[uid];
          final name = user == null
              ? (userData.containsKey(uid) ? "Unknown User" : "Loading...")
              : (user.name.isEmpty ? user.username : user.name);
          final imageUrl = user?.profileImage as String?;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepOrange,
              backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                  ? NetworkImage(imageUrl)
                  : null,
              child: (imageUrl == null || imageUrl.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            title: Text(name),
            subtitle: Text("@$uid"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OtherProfileScreen(userId: uid),
                ),
              );
            },
          );
        },
      ),
    );
  }
}