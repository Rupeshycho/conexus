import 'package:flutter/material.dart';

class MessageFrame extends StatefulWidget {
  const MessageFrame({super.key});

  @override
  State<MessageFrame> createState() => _MessageFrameState();
}

class _MessageFrameState extends State<MessageFrame> {
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
        ],
      ),

    );
  }
}

