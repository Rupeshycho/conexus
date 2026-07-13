import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'other_profile_screen.dart';

class FollowersList extends StatefulWidget {
  final List<String> followers;

  const FollowersList({super.key, required this.followers});

  @override
  State<FollowersList> createState() => _FollowersListState();
}

class _FollowersListState extends State<FollowersList> {
  Map<String, dynamic> userData = {}; // stores the full UserModel per uid

  @override
  void initState() {
    super.initState();
    _loadUserNames();
  }

  Future<void> _loadUserNames() async {
    final userVM = context.read<UserViewModel>();
    Map<String, dynamic> data = {};

    for (String uid in widget.followers) {
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
          "Followers",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepOrange,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: widget.followers.isEmpty
          ? const Center(
        child: Text(
          "No Followers Yet",
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        itemCount: widget.followers.length,
        itemBuilder: (context, index) {
          final uid = widget.followers[index];
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