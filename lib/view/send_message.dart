import 'package:flutter/material.dart';
import 'chat_tile.dart';

class MessageFrame extends StatefulWidget {
  const MessageFrame({super.key});

  @override
  State<MessageFrame> createState() =>
      _MessageFrameState();
}

class _MessageFrameState
    extends State<MessageFrame> {

  // SEARCH CONTROLLER

  final TextEditingController
  searchController =
  TextEditingController();

  // Dummy CHAT DATA

  final List<Map<String, dynamic>>
  allChats = [

    {
      "name": "Aarav",
      "message": "Hey, how are you?",
      "time": "2:30 PM",
      "image": "https://i.pravatar.cc/150?img=1",
      "unread": "2",
      "online": true,
    },

    {
      "name": "Hari",
      "message": "Let's meet tomorrow.",
      "time": "1:10 PM",
      "image": "https://i.pravatar.cc/150?img=2",
      "unread": "1",
      "online": false,
    },

    {
      "name": "Daku",
      "message": "I sent the files.",
      "time": "Yesterday",
      "image": "https://i.pravatar.cc/150?img=3",
      "unread": "0",
      "online": true,
    },

    {
      "name": "Joe",
      "message": "Are you ok?",
      "time": "Yesterday",
      "image": "https://i.pravatar.cc/150?img=4",
      "unread": "4",
      "online": false,
    },

    {
      "name": "Julia",
      "message":
      "If you are free, message me!",
      "time": "Monday",
      "image": "https://i.pravatar.cc/150?img=5",
      "unread": "3",
      "online": true,
    },
  ];

  // FILTERED CHAT LIST

  List<Map<String, dynamic>>
  filteredChats = [];

  @override
  void initState() {
    super.initState();
    filteredChats = List.from(allChats);
  }

  // SEARCH FUNCTION
  void searchUser(String query) {

    if (query.isEmpty) {setState(() {
      filteredChats =
            List.from(allChats);
      });
      return;
    }

    final results = allChats.where((chat) {
      final name = chat["name"].toString().toLowerCase();
      return name.contains(query.toLowerCase(),);
    }).toList();

    setState(() {
      filteredChats = results;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),

      // APP BAR
      appBar: AppBar(

        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text("Messages", style: TextStyle(
            color: Colors.black,
            fontWeight:
            FontWeight.bold,
            fontSize: 24,
          ),
        ),

        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.edit,
              color: Colors.black,
            ),
          ),

          const SizedBox(width: 6),
        ],
      ),

      // BODY

      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18,),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),

              child: TextField(
                controller: searchController,
                onChanged: searchUser,
                cursorColor: Colors.orange,
                decoration: InputDecoration(hintText: "Search users...",
                  hintStyle: TextStyle(
                    color:
                    Colors.grey.shade500,
                  ),

                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.orange,
                  ),

                  suffixIcon: searchController.text.isNotEmpty ?
                  IconButton(
                    onPressed: () {
                      searchController.clear();
                      searchUser("");
                    },

                    icon: const Icon(Icons.close,),) : null,
                  border: InputBorder.none,

                  contentPadding: const EdgeInsets.symmetric(vertical: 16,),
                ),
              ),
            ),
          ),

          // ACTIVE USERS
          SizedBox(
            height: 90,
            child: ListView.builder(

              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14,),

              itemCount: filteredChats.length,

              itemBuilder: (context, index) {
                final chat = filteredChats[index];
                return Padding(

                  padding: const EdgeInsets.only(right: 14,),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundImage: NetworkImage(chat["image"],),
                          ),

                          if (chat["online"])
                            Positioned(
                              bottom: 2,
                              right: 2,

                              child: Container(
                                height: 14,
                                width: 14,

                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,

                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      Text(
                        chat["name"],

                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // CHAT LIST
          Expanded(

            child: filteredChats.isEmpty ?
            const Center(
              child: Text("No users found", style: TextStyle(
                  fontSize: 16,
                ),
              ),
            )
                : ListView.builder(
              physics: const BouncingScrollPhysics(),

              itemCount: filteredChats.length,
              itemBuilder: (context, index) {
                final chat = filteredChats[index];
                return ChatTile(

                  username: chat["name"],

                  profileImage: chat["image"],

                  lastMessage: chat["message"],

                  time: chat["time"],

                  unreadCount: chat["unread"],

                  isOnline: chat["online"],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}