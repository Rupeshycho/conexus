import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:conexus/model/user_model.dart';
import 'package:conexus/viewmodel/user_view_model.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();

  // Track selection by id rather than by UserModel instance: `contains`
  // on a List<UserModel> depends on UserModel overriding ==, which it may
  // not. Ids are always comparable and this also avoids O(n) list removal.
  final Set<String> _selectedUserIds = {};
  bool _isLoading = false;

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Group name is required")));
      return;
    }
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Select at least 1 member")));
      return;
    }

    setState(() => _isLoading = true);

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final currentUserInfo = context.read<UserViewModel>().user;
    final allUsers = context.read<UserViewModel>().allUsers ?? [];
    final selectedUsers =
    allUsers.where((u) => _selectedUserIds.contains(u.id)).toList();

    final participants = [currentUserId, ...selectedUsers.map((e) => e.id)];
    final names = <String, String>{};
    final profileImages = <String, String>{};
    final unreadCount = <String, int>{};

    if (currentUserInfo != null) {
      names[currentUserId] = currentUserInfo.name;
      profileImages[currentUserId] = currentUserInfo.profileImage;
    }

    for (final u in selectedUsers) {
      names[u.id] = u.name;
      profileImages[u.id] = u.profileImage;
      unreadCount[u.id] = 1; // 1 initial unread for the welcome message
    }

    try {
      final docRef = FirebaseFirestore.instance.collection('chat_rooms').doc();
      final now = FieldValue.serverTimestamp();

      await docRef.set({
        'isGroup': true,
        'groupName': groupName,
        'groupImage':
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(groupName)}&background=random',
        'participants': participants,
        'lastMessage': 'Group created',
        'lastMessageSenderId': currentUserId,
        'lastMessageTime': now,
        'names': names,
        'profileImages': profileImages,
        'unreadCount': unreadCount,
      });

      // Add welcome message
      await docRef.collection('messages').add({
        'text': 'Group "$groupName" created.',
        'imageUrl': '',
        'type': 'system',
        'status': 'sent',
        'isEdited': false,
        'senderId': currentUserId,
        'receiverId': '',
        'time': now,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Group created successfully!")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final users =
    (viewModel.allUsers ?? []).where((u) => u.id != currentUserId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Group"),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _createGroup,
              child: const Text("Create",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: IgnorePointer(
        // Prevent editing the name or selection while a create request is
        // in flight — the button already disappears, but the fields
        // underneath were still interactive before this.
        ignoring: _isLoading,
        child: Opacity(
          opacity: _isLoading ? 0.6 : 1,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _groupNameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: "Group Name",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _selectedUserIds.isEmpty
                        ? "Select Members"
                        : "Select Members (${_selectedUserIds.length} selected)",
                    style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              Expanded(
                child: users.isEmpty
                    ? const Center(
                  child: Text(
                    "No other users found",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                    : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = _selectedUserIds.contains(user.id);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.profileImage.isNotEmpty
                            ? NetworkImage(user.profileImage)
                            : null,
                        child: user.profileImage.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(user.name),
                      subtitle: Text(user.email),
                      trailing: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: isSelected ? Colors.orange : Colors.grey,
                      ),
                      onTap: () => _toggleSelection(user.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}