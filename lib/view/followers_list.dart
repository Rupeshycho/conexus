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
  Map<String, String> userNames = {};

  @override
  void initState() {
    super.initState();
    _loadUserNames();
  }

  Future<void> _loadUserNames() async {
    final userVM = context.read<UserViewModel>();
    Map<String, String> names = {};

    for (String uid in widget.followers) {
      try {
        final user = await userVM.getUser(uid);
        names[uid] = user.name.isEmpty ? user.username : user.name;
      } catch (e) {
        names[uid] = "Unknown User";
      }
    }

    setState(() {
      userNames = names;
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
          final name = userNames[uid] ?? "Loading...";

          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.deepOrange,
              child: Icon(Icons.person, color: Colors.white),
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