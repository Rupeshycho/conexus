import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import "package:firebase_auth/firebase_auth.dart";
import 'package:conexus/viewmodel/user_view_model.dart';
import 'chat_tile.dart';
import 'select_user_screen.dart';
import 'message_individual_frame.dart';
import 'profile_screen.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';

class MessageFrame extends StatefulWidget {
  const MessageFrame({super.key});

  @override
  State<MessageFrame> createState() => _MessageFrameState();
}

class _ChatRoomData {
  final String chatRoomId;
  final bool isGroup;
  final String displayTitle;
  final String displayImage;
  final String lastMessage;
  final Timestamp? lastMessageTime;
  final int unreadCount;
  final String otherUserId;

  const _ChatRoomData({
    required this.chatRoomId,
    required this.isGroup,
    required this.displayTitle,
    required this.displayImage,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.otherUserId,
  });

  factory _ChatRoomData.fromDoc(
      QueryDocumentSnapshot doc, String currentUserId) {
    final data = doc.data() as Map<String, dynamic>;
    final isGroup = data['isGroup'] == true;

    final participants = List<String>.from(data['participants'] ?? []);
    final otherUserId = participants.firstWhere(
          (id) => id != currentUserId,
      orElse: () => '',
    );

    final names = Map<String, dynamic>.from(data['names'] ?? {});
    final profileImages =
    Map<String, dynamic>.from(data['profileImages'] ?? {});
    final unreadMap = Map<String, dynamic>.from(data['unreadCount'] ?? {});

    final displayTitle = isGroup
        ? (data['groupName']?.toString() ?? 'Group')
        : (names[otherUserId]?.toString() ?? 'User');

    final displayImage = isGroup
        ? (data['groupImage']?.toString() ??
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayTitle)}&background=random')
        : (profileImages[otherUserId]?.toString() ??
        'https://i.pravatar.cc/150?u=$otherUserId');

    return _ChatRoomData(
      chatRoomId: doc.id,
      isGroup: isGroup,
      displayTitle: displayTitle,
      displayImage: displayImage,
      lastMessage: data['lastMessage']?.toString() ?? '',
      lastMessageTime: data['lastMessageTime'] as Timestamp?,
      // unreadCount values come from Firestore as num; coerce once here so
      // ChatTile always receives a real int instead of a stringified one.
      unreadCount: (unreadMap[currentUserId] as num?)?.toInt() ?? 0,
      otherUserId: otherUserId,
    );
  }
}

class _MessageFrameState extends State<MessageFrame> {
  final TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  late final Stream<QuerySnapshot> chatRoomStream;
  late final String currentUserId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserViewModel>().getAllUser();
    });

    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Stream created once (not in build) so StreamBuilder doesn't resubscribe
    // on every rebuild.
    chatRoomStream = FirebaseFirestore.instance
        .collection('chat_rooms')
        .where('participants', arrayContains: currentUserId)
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
      final hour =
      date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? "PM" : "AM";
      return "$hour:${date.minute.toString().padLeft(2, '0')} $amPm";
    } else if (diff.inDays == 1) {
      return "Yesterday";
    } else if (diff.inDays < 7) {
      const weekdays = [
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

  void _openChat(_ChatRoomData room) {
    // Fire-and-forget: reset unread count for the current user. Errors are
    // swallowed on purpose (non-critical, shouldn't block navigation) but
    // logged so they're not silently lost.
    FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(room.chatRoomId)
        .update({'unreadCount.$currentUserId': 0}).catchError((e) {
      debugPrint('Failed to reset unread count for ${room.chatRoomId}: $e');
    });

    if (room.isGroup) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            chatRoomId: room.chatRoomId,
            groupName: room.displayTitle,
            groupImage: room.displayImage,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            receiverId: room.otherUserId,
            username: room.displayTitle,
            profileImage: room.displayImage,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // context.read (not watch): this screen doesn't rebuild on user-list
    // changes on its own, it reads the current snapshot each build.
    final viewModel = context.read<UserViewModel>();

    final horizontalUsers = (viewModel.allUsers ?? [])
        .where((u) => u.id != currentUserId)
        .where((u) => u.name.toLowerCase().contains(searchQuery.toLowerCase()))
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
              // Was `vm.user`, which doesn't match the real getter
              // (`currentUser`, confirmed by profile_screen.dart) — that
              // meant this avatar was silently always null.
              final currentUser = vm.currentUser;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.orange.shade200,
                    backgroundImage: currentUser != null &&
                        currentUser.profileImage.isNotEmpty
                        ? NetworkImage(currentUser.profileImage)
                        : null,
                    child: currentUser == null ||
                        currentUser.profileImage.isEmpty
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
                MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
              );
            },
            icon: const Icon(Icons.group_add),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SelectUserScreen()),
              );
            },
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search users...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  onPressed: () {
                    searchController.clear();
                    setState(() => searchQuery = "");
                  },
                  icon: const Icon(Icons.close),
                )
                    : null,
              ),
            ),
          ),

          // HORIZONTAL USER LIST
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
              stream: chatRoomStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData) {
                  return const Center(child: Text("No data"));
                }

                final chatDocs = snapshot.data!.docs;

                if (chatDocs.isEmpty) {
                  return const Center(child: Text("No chats found"));
                }

                // Parse each doc exactly once.
                final rooms = chatDocs
                    .map((doc) => _ChatRoomData.fromDoc(doc, currentUserId))
                    .toList();

                rooms.sort((a, b) {
                  final aTime = a.lastMessageTime;
                  final bTime = b.lastMessageTime;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                final query = searchQuery.toLowerCase();
                final filteredRooms = query.isEmpty
                    ? rooms
                    : rooms
                    .where((r) =>
                    r.displayTitle.toLowerCase().contains(query))
                    .toList();

                if (filteredRooms.isEmpty) {
                  return const Center(
                    child: Text(
                      "No matches found",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredRooms.length,
                  itemBuilder: (context, index) {
                    final room = filteredRooms[index];

                    return ChatTile(
                      key: ValueKey(room.chatRoomId),
                      username: room.displayTitle,
                      profileImage: room.displayImage,
                      lastMessage: room.lastMessage,
                      time: formatTimestamp(room.lastMessageTime),
                      unreadCount: room.unreadCount,
                      // NOTE: this reflects "is a 1:1 chat", not real
                      // presence — there's no online-status source yet.
                      // Wire this up to a presence collection/RTDB when
                      // that's available; leaving as-is for now to avoid
                      // faking a feature that doesn't exist server-side.
                      isOnline: !room.isGroup,
                      onTap: () => _openChat(room),
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