import 'package:flutter/material.dart';

import 'message_individual_frame.dart';

class MessageFrame extends StatefulWidget {
  const MessageFrame({super.key});

  @override
  State<MessageFrame> createState() =>
      _MessageFrameState();
}

class _MessageFrameState
    extends State<MessageFrame> {

  final List<Map<String, dynamic>> chats = [

    {
      "name": "Aarav",
      "message": "Hey, how are you?",
      "time": "2:30 PM",
      "image":
      "https://i.pravatar.cc/150?img=1",
      "unread": "2",
      "online": true,
    },

    {
      "name": "Hari",
      "message": "Let's meet tomorrow.",
      "time": "1:10 PM",
      "image":
      "https://i.pravatar.cc/150?img=2",
      "unread": "1",
      "online": false,
    },

    {
      "name": "Daku",
      "message": "I sent the files.",
      "time": "Yesterday",
      "image":
      "https://i.pravatar.cc/150?img=3",
      "unread": "0",
      "online": true,
    },

    {
      "name": "Joe",
      "message": "Are you ok?",
      "time": "Yesterday",
      "image":
      "https://i.pravatar.cc/150?img=4",
      "unread": "4",
      "online": false,
    },

    {
      "name": "Julia",
      "message":
      "If you are free, message me!",
      "time": "Monday",
      "image":
      "https://i.pravatar.cc/150?img=5",
      "unread": "3",
      "online": true,
    },
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
      const Color(0xFFF4F6FA),

      appBar: AppBar(

        backgroundColor: Colors.white,
        elevation: 0,

        title: const Text(
          "Messages",

          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: ListView.builder(

        itemCount: chats.length,

        itemBuilder: (context, index) {

          final chat = chats[index];

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
    );
  }
}