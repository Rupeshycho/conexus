import 'package:flutter/material.dart';
import 'video_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String username;
  final String profileImage;

  const ChatScreen({
    super.key,
    required this.username,
    required this.profileImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {

  final TextEditingController messageController =
  TextEditingController();

  final ScrollController scrollController =
  ScrollController();

  // DUMMY CHAT DATA

  final List<Map<String, dynamic>> messages = [

    {
      "text": "Hello 👋",
      "isMe": false,
      "time": "10:20 AM",
    },

    {
      "text": "Hi bro!",
      "isMe": true,
      "time": "10:21 AM",
    },

    {
      "text": "How are you?",
      "isMe": false,
      "time": "10:22 AM",
    },
  ];

  // SEND MESSAGE

  void sendMessage() {

    if (messageController.text.trim().isEmpty) {
      return;
    }

    setState(() {

      messages.add({

        "text": messageController.text.trim(),

        "isMe": true,

        "time": TimeOfDay.now().format(context),
      });
    });

    messageController.clear();

    // AUTO SCROLL

    Future.delayed(
      const Duration(milliseconds: 100), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,

            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      },
    );
  }

  // AUDIO CALL

  void startAudioCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          username: widget.username,
          isVideoEnabled: false,
        ),
      ),
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),

      // APP BAR

      appBar: AppBar(

        backgroundColor: Colors.white,

        elevation: 0,

        leading: IconButton(

          onPressed: () {
            Navigator.pop(context);
          },

          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black,
          ),
        ),

        title: Row(
          children: [

            CircleAvatar(
              radius: 20,

              backgroundImage:
              NetworkImage(
                widget.profileImage,
              ),
            ),

            const SizedBox(width: 10),

            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [

                Text(
                  widget.username,

                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 2),

                const Text(
                  "Online",

                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),

        actions: [

          // VIDEO CALL

          IconButton(

            icon: const Icon(
              Icons.videocam,
              color: Colors.black,
            ),

            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoCallScreen(
                    username: widget.username,
                    isVideoEnabled: true,
                  ),
                ),
              );
            },
          ),

          // AUDIO CALL

          // AUDIO CALL

          IconButton(
            icon: const Icon(
              Icons.call,
              color: Colors.black,
            ),
            onPressed: startAudioCall,
          ),

          const SizedBox(width: 5),

          const SizedBox(width: 5),
        ],
      ),

      // BODY

      body: Column(
        children: [

          // MESSAGE LIST

          Expanded(

            child: ListView.builder(

              controller: scrollController,

              padding: const EdgeInsets.all(16),

              itemCount: messages.length,

              itemBuilder: (context, index) {

                final msg = messages[index];

                final bool isMe = msg["isMe"];
                return Align(

                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,

                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,

                    children: [

                      Container(

                        margin: const EdgeInsets.only(bottom: 4,),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),

                        constraints:
                        const BoxConstraints(maxWidth: 280,),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.orange
                              : Colors.white,

                          borderRadius: BorderRadius.circular(18,),
                        ),

                        child: Text(msg["text"],
                          style: TextStyle(
                            color:
                            isMe
                                ? Colors.white
                                : Colors.black,
                            fontSize: 15,
                          ),
                        ),
                      ),

                      Padding(

                        padding: const EdgeInsets.only(
                          bottom: 12,
                          left: 6,
                          right: 6,
                        ),

                        child: Text(msg["time"],
                          style: TextStyle(
                            color:
                            Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // INPUT AREA

          Container(

            padding:
            const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),

            decoration: const BoxDecoration(
              color: Colors.white,
            ),

            child: Row(
              children: [

                // TEXT FIELD

                Expanded(

                  child: TextField(

                    controller:
                    messageController,

                    cursorColor:
                    Colors.orange,

                    decoration:
                    InputDecoration(

                      hintText:
                      "Type message...",

                      filled: true,

                      fillColor:
                      Colors.grey.shade100,

                      contentPadding:
                      const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),

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

                // SEND BUTTON

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