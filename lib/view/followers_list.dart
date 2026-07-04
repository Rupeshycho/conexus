import 'package:flutter/material.dart';

class FollowersList extends StatelessWidget {
  final List<String> followers;

  const FollowersList({
    super.key,
    required this.followers,
  });

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
      body: followers.isEmpty
          ? const Center(
        child: Text(
          "No Followers Yet",
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        itemCount: followers.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.deepOrange,
              child: Icon(
                Icons.person,
                color: Colors.white,
              ),
            ),
            title: Text(followers[index]),
          );
        },
      ),
    );
  }
}