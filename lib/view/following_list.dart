import 'package:flutter/material.dart';

class FollowingList extends StatelessWidget {
  final List<String> following;

  const FollowingList({
    super.key,
    required this.following,
  });

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
      body: following.isEmpty
          ? const Center(
        child: Text(
          "Not Following Anyone",
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        itemCount: following.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.deepOrange,
              child: Icon(
                Icons.person,
                color: Colors.white,
              ),
            ),
            title: Text(following[index]),
          );
        },
      ),
    );
  }
}