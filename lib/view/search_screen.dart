import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'other_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchUser {
  final String uid;
  final String username;
  final String email;
  final String profileImage;

  _SearchUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.profileImage,
  });

  factory _SearchUser.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return _SearchUser(
      uid: doc.id,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      // Matches the field name UserModel.fromMap reads elsewhere
      // (ProfileScreen/OtherProfileScreen use user.profileImage) —
      // was previously reading a non-existent 'photoUrl' field.
      profileImage: data['profileImage'] ?? '',
    );
  }
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<_SearchUser> _allUsers = [];
  List<_SearchUser> filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final snapshot = await _firestore.collection('users').get();

      _allUsers = snapshot.docs
          .map((doc) => _SearchUser.fromDoc(doc))
          .where((user) => user.uid != currentUid)
          .toList();

      filteredUsers = _allUsers;
    } catch (e) {
      debugPrint('Error loading users: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void searchUser(String value) {
    final query = value.trim().toLowerCase();
    setState(() {
      filteredUsers = _allUsers.where((user) {
        return user.username.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              onChanged: searchUser,
              decoration: InputDecoration(
                hintText: "Search by username or email...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredUsers.isEmpty
                  ? const Center(child: Text("No users found"))
                  : ListView.builder(
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundImage: user.profileImage.isNotEmpty
                                  ? NetworkImage(user.profileImage)
                                  : null,
                              onBackgroundImageError:
                                  user.profileImage.isNotEmpty
                                  ? (_, __) {
                                      debugPrint(
                                        'Failed to load avatar for ${user.username}',
                                      );
                                    }
                                  : null,
                              child: user.profileImage.isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(user.username),
                            subtitle: user.email.isNotEmpty
                                ? Text(user.email)
                                : null,
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      OtherProfileScreen(userId: user.uid),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
