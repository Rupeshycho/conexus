import 'package:flutter/material.dart';

class ChatTile extends StatelessWidget {

  final String username;
  final String profileImage;
  final String lastMessage;
  final String time;
  final String unreadCount;
  final bool isOnline;

  const ChatTile({
    super.key,
    required this.username,
    required this.profileImage,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {

    return InkWell(

      onTap: () {

        Navigator.push(
          context,

          MaterialPageRoute(
            builder: (context) => ChatScreen(

              username: username,

              profileImage: profileImage,
            ),
          ),
        );
      },

      child: Container(

        margin: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 7,
        ),

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius:
          BorderRadius.circular(18),
        ),

        child: Row(
          children: [

            Stack(
              children: [

                CircleAvatar(
                  radius: 28,

                  backgroundImage:
                  NetworkImage(profileImage),
                ),

                if (isOnline)
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

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [

                  Text(
                    username,

                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    lastMessage,

                    overflow:
                    TextOverflow.ellipsis,

                    style: TextStyle(
                      color:
                      Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            Column(
              children: [

                Text(
                  time,

                  style: TextStyle(
                    fontSize: 12,
                    color:
                    Colors.grey.shade500,
                  ),
                ),

                const SizedBox(height: 8),

                if (unreadCount != "0")
                  Container(

                    padding:
                    const EdgeInsets.all(7),

                    decoration:
                    const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),

                    child: Text(
                      unreadCount,

                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// CHAT SCREEN


class ChatScreen extends StatefulWidget {

  final String username;
  final String profileImage;

  const ChatScreen({
    super.key,
    required this.username,
    required this.profileImage,
  });

  @override
  State<ChatScreen> createState() =>
      _ChatScreenState();
}

class _ChatScreenState
    extends State<ChatScreen> {

  final TextEditingController
  messageController =
  TextEditingController();

  final List<Map<String, dynamic>>
  messages = [];

  void sendMessage() {

    if (messageController.text
        .trim()
        .isEmpty) {
      return;
    }

    setState(() {

      messages.add({

        "text":
        messageController.text.trim(),

        "isMe": true,
      });
    });

    messageController.clear();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
      const Color(0xFFF4F6FA),

      appBar: AppBar(

        backgroundColor: Colors.white,

        title: Row(
          children: [

            CircleAvatar(
              backgroundImage:
              NetworkImage(
                widget.profileImage,
              ),
            ),

            const SizedBox(width: 10),

            Text(
              widget.username,

              style: const TextStyle(
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),

      body: Column(
        children: [

          Expanded(
            child: ListView.builder(

              padding:
              const EdgeInsets.all(16),

              itemCount:
              messages.length,

              itemBuilder:
                  (context, index) {

                final message =
                messages[index];

                final bool isMe =
                message["isMe"];

                return Align(

                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,

                  child: Container(

                    margin:
                    const EdgeInsets.only(
                      bottom: 12,
                    ),

                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),

                    decoration: BoxDecoration(

                      color: isMe
                          ? Colors.orange
                          : Colors.white,

                      borderRadius:
                      BorderRadius.circular(
                        18,
                      ),
                    ),

                    child: Text(

                      message["text"],

                      style: TextStyle(
                        color: isMe
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Container(

            padding:
            const EdgeInsets.all(12),

            color: Colors.white,

            child: Row(
              children: [

                Expanded(
                  child: TextField(

                    controller:
                    messageController,

                    decoration:
                    InputDecoration(

                      hintText:
                      "Type message...",

                      filled: true,

                      fillColor:
                      Colors.grey.shade100,

                      border:
                      OutlineInputBorder(

                        borderRadius:
                        BorderRadius.circular(
                          30,
                        ),

                        borderSide:
                        BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                GestureDetector(

                  onTap: sendMessage,

                  child: Container(

                    height: 52,
                    width: 52,

                    decoration:
                    const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),

                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}