import 'package:flutter/material.dart';

class VideoCallScreen extends StatefulWidget {
  final String username;

  const VideoCallScreen({
    super.key,
    required this.username,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {

  bool isMuted = false;
  bool isVideoOn = true;
  bool isScreenSharing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: SafeArea(
        child: Column(
          children: [

            // TOP BAR
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [

                  // BACK BUTTON
                  CircleAvatar(
                    backgroundColor: Colors.white12,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),

                  const Text(
                    "Video Call",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(width: 45),
                ],
              ),
            ),

            const Spacer(),

            // PROFILE IMAGE
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey.shade800,
              child: Text(
                widget.username[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 45,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // USERNAME
            Text(
              widget.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            // STATUS
            Text(
              isVideoOn
                  ? "Video Calling..."
                  : "Voice Calling...",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),

            const Spacer(),

            // BOTTOM BUTTONS
            Padding(
              padding: const EdgeInsets.only(
                bottom: 40,
                left: 20,
                right: 20,
              ),
              child: Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceEvenly,
                children: [

                  // MUTE BUTTON
                  _buildButton(
                    icon: isMuted
                        ? Icons.mic_off
                        : Icons.mic,
                    color:
                    isMuted ? Colors.red : Colors.white24,
                    onTap: () {
                      setState(() {
                        isMuted = !isMuted;
                      });
                    },
                  ),

                  // VIDEO ON/OFF
                  _buildButton(
                    icon: isVideoOn
                        ? Icons.videocam
                        : Icons.videocam_off,
                    color:
                    isVideoOn ? Colors.white24 : Colors.orange,
                    onTap: () {
                      setState(() {
                        isVideoOn = !isVideoOn;
                      });
                    },
                  ),
                  // SCREEN SHARE BUTTON

                  _buildButton(
                    icon: isScreenSharing
                        ? Icons.stop_screen_share_rounded
                        : Icons.screen_share_rounded,

                    // Elegant colors (modern UI style)
                    color: isScreenSharing
                        ? const Color(0xFFE53935) // soft modern red (stop state)
                        : const Color(0xFF1E88E5), // elegant blue (start state)

                    onTap: () {
                      setState(() {
                        isScreenSharing = !isScreenSharing;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 1),
                          backgroundColor: isScreenSharing
                              ? const Color(0xFF1E88E5)
                              : const Color(0xFFE53935),
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          content: Text(
                            isScreenSharing
                                ? "Screen sharing started"
                                : "Screen sharing stopped",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // END CALL BUTTON
                  _buildButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // BUTTON WIDGET
  Widget _buildButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}