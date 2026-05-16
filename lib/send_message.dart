import 'package:flutter/material.dart';

class MessageFrame extends StatefulWidget {
  const MessageFrame({super.key});

  @override
  State<MessageFrame> createState() => _MessageFrameState();
}
class _MessageFrameState extends State<MessageFrame> {

  // dummy data
  final List<Map<String, dynamic>> chats = [
    {
      "name": "Aarav",
      "message": "Hey, how are you?",
      "time": "2:30 PM",
      "image":
      "https://i.pravatar.cc/150?img=1",
    },
    {
      "name": "hari",
      "message": "Let's meet tomorrow.",
      "time": "1:10 PM",
      "image":
      "https://i.pravatar.cc/150?img=2",
    },
    {
      "name": "daku",
      "message": "I sent the files.",
      "time": "Yesterday",
      "image":
      "https://i.pravatar.cc/150?img=3",
    },
    {
      "name": "joe",
      "message": "are you ok ?",
      "time": "Yesterday",
      "image":
      "https://i.pravatar.cc/150?img=4",
    },
    {
      "name": "julia",
      "message": "if you are free,message me !",
      "time": "Monday",
      "image":
      "https://i.pravatar.cc/150?img=5",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),

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
            size: 20,
          ),
        ),

        title: const Text("Messages", style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,

        actions: [

          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.more_vert,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),

            child: Container(
              height: 55,

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),

              child: TextField(

                cursorColor: Colors.orange,

                decoration: InputDecoration(

                  hintText: "Search conversations",

                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),

                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),

                  border: InputBorder.none,

                  contentPadding:
                  const EdgeInsets.symmetric(
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),

          // Chat_cards
          Expanded(
            child: ListView.builder(
              itemCount: chats.length,

              itemBuilder: (context, index) {

                final chat = chats[index];

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),

                  child: Container(
                    padding: const EdgeInsets.all(14),

                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),

                    child: Row(
                      children: [

                        // Profile Image
                        CircleAvatar(
                          radius: 28,
                          backgroundImage:
                          NetworkImage(chat["image"]),
                        ),

                        const SizedBox(width: 14),

                        // Name & Message
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,

                            children: [

                              Text(
                                chat["name"],

                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),

                              const SizedBox(height: 5),

                              Text(
                                chat["message"],

                                overflow: TextOverflow.ellipsis,

                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Time
                        Text(
                          chat["time"],

                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

    );
  }
}

