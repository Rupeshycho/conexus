import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:conexus/viewmodel/user_view_model.dart';
import 'chat_tile.dart';
import 'select_user_screen.dart';
import 'package:conexus/viewmodel/theme_view_model.dart';
import 'message_individual_frame.dart';
import 'profile_screen.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';

class MessageFrame extends StatefulWidget {
  const MessageFrame({super.key});

  @override
  State<MessageFrame> createState() => _MessageFrameState();
}

class _MessageFrameState extends State<MessageFrame> {
  final TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  late final Stream<QuerySnapshot> chatRoomStream;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserViewModel>().getAllUser();
    });

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // ✅ FIX: stream created ONCE (not in build)
    chatRoomStream = FirebaseFirestore.instance
        .collection('chat_rooms')
        .where('participants', arrayContains: uid)
        .snapshots();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      final hour = date.hour > 12
          ? date.hour - 12
          : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? "PM" : "AM";
      return "$hour:${date.minute.toString().padLeft(2, '0')} $amPm";
    } else if (diff.inDays == 1) {
      return "Yesterday";
    } else if (diff.inDays < 7) {
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      return weekdays[date.weekday - 1];
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeViewModel = context.watch<ThemeViewModel>();
    final isDark = themeViewModel.isDarkMode;

    // ⚠️ FIX: avoid rebuild chain issue
    final viewModel = context.read<UserViewModel>();

    final currentUserId =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    final horizontalUsers = (viewModel.allUsers ?? [])
        .where((u) => u.id != currentUserId)
        .where((u) => u.name
        .toLowerCase()
        .contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Messages",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [

          Consumer<UserViewModel>(
            builder: (context, vm, child) {
              final currentUser = vm.user;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfileScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.orange.shade200,
                    backgroundImage: currentUser != null && currentUser.profileImage.isNotEmpty
                        ? NetworkImage(currentUser.profileImage)
                        : null,
                    child: currentUser == null || currentUser.profileImage.isEmpty
                        ? const Icon(Icons.person, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              );
            },
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateGroupScreen(),
                ),
              );
            },
            icon: const Icon(Icons.group_add),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SelectUserScreen(),
                ),
              );
            },
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            onPressed: () {
              viewModel.logout();
            },
            icon: const Icon(Icons.logout, color: Colors.red),
          ),
        ],
      ),

      body: Column(
        children: [
          // SEARCH BAR (UNCHANGED)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onChanged: (val) {
                setState(() {
                  searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: "Search users...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  onPressed: () {
                    searchController.clear();
                    setState(() {
                      searchQuery = "";
                    });
                  },
                  icon: const Icon(Icons.close),
                )
                    : null,
              ),
            ),
          ),

          // USERS LIST (UNCHANGED)
          if (horizontalUsers.isNotEmpty) ...[
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: horizontalUsers.length,
                itemBuilder: (context, index) {
                  final user = horizontalUsers[index];

                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              receiverId: user.id,
                              username: user.name,
                              profileImage: user.profileImage,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundImage: NetworkImage(
                              user.profileImage.isNotEmpty
                                  ? user.profileImage
                                  : 'https://i.pravatar.cc/150?u=${user.id}',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user.name.split(' ')[0],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // ✅ FIX: stable stream
              stream: chatRoomStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text("Error: ${snapshot.error}"),
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: Text("No data"),
                  );
                }

                final chatDocs = snapshot.data!.docs.toList();

                if (chatDocs.isEmpty) {
                  return const Center(
                    child: Text("No chats found"),
                  );
                }

                chatDocs.sort((a, b) {
                  final aTime =
                  (a.data() as Map)['lastMessageTime']
                  as Timestamp?;
                  final bTime =
                  (b.data() as Map)['lastMessageTime']
                  as Timestamp?;

                  if (aTime == null) return 1;
                  if (bTime == null) return -1;

                  return bTime.compareTo(aTime);
                });

                // Filter by search query
                final filteredDocs = chatDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final participants = List<String>.from(data['participants'] ?? []);
                  final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
                  final names = Map<String, dynamic>.from(data['names'] ?? {});
                  final otherUserName = names[otherUserId]?.toString().toLowerCase() ?? '';
                  final groupName = data['groupName']?.toString().toLowerCase() ?? '';
                  final query = searchQuery.toLowerCase();
                  return otherUserName.contains(query) || groupName.contains(query);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text("No matches found", style: TextStyle(fontSize: 16, color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    final chatRoomId = filteredDocs[index].id;
                    final isGroup = data['isGroup'] == true;

                    final participants = List<String>.from(data['participants'] ?? []);
                    final otherUserId = participants.firstWhere(
                          (id) => id != currentUserId,
                      orElse: () => '',
                    );

                    final names = Map<String, dynamic>.from(data['names'] ?? {});
                    final profileImages = Map<String, dynamic>.from(data['profileImages'] ?? {});
                    final unreadMap = Map<String, dynamic>.from(data['unreadCount'] ?? {});

                    final displayTitle = isGroup
                        ? (data['groupName']?.toString() ?? 'Group')
                        : (names[otherUserId]?.toString() ?? 'User');

                    final displayImage = isGroup
                        ? (data['groupImage']?.toString() ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayTitle)}&background=random')
                        : (profileImages[otherUserId]?.toString() ?? 'https://i.pravatar.cc/150?u=$otherUserId');

                    final lastMsg = data['lastMessage']?.toString() ?? '';
                    final lastMsgTime = data['lastMessageTime'] as Timestamp?;
                    final unreadCount = unreadMap[currentUserId]?.toString() ?? '0';

                    return ChatTile(
                      username: displayTitle,
                      profileImage: displayImage,
                      lastMessage: lastMsg,
                      time: formatTimestamp(lastMsgTime),
                      unreadCount: unreadCount,
                      isOnline: !isGroup,
                      onTap: () {
                        // Reset unread count
                        FirebaseFirestore.instance
                            .collection('chat_rooms')
                            .doc(chatRoomId)
                            .update({'unreadCount.$currentUserId': 0});

                        if (isGroup) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupChatScreen(
                                chatRoomId: chatRoomId,
                                groupName: displayTitle,
                                groupImage: displayImage,
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                receiverId: otherUserId,
                                username: displayTitle,
                                profileImage: displayImage,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}