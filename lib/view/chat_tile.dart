import 'package:flutter/material.dart';
import 'message_individual_frame.dart';

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

      borderRadius: BorderRadius.circular(18),

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

          boxShadow: [

            BoxShadow(
              color:
              Colors.black.withOpacity(0.03),

              blurRadius: 8,

              offset: const Offset(0, 3),
            ),
          ],
        ),

        child: Row(
          children: [

            // PROFILE IMAGE

            Stack(
              children: [

                CircleAvatar(
                  radius: 30,

                  backgroundImage:
                  NetworkImage(profileImage),
                ),

                // ONLINE INDICATOR

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

            // USER INFO

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [

                  Text(username, style: const TextStyle(
                      fontSize: 17,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                      Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // TIME + UNREAD

            Column(
              crossAxisAlignment:
              CrossAxisAlignment.end,

              children: [
                Text(time, style: TextStyle(
                    fontSize: 12,
                    color:
                    Colors.grey.shade500,
                  ),
                ),

                const SizedBox(height: 8),

                if (unreadCount != "0")
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),

                    child: Text(unreadCount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight:
                        FontWeight.bold,
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