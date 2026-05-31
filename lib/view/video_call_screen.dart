import 'dart:async';
import 'package:flutter/material.dart';

class VideoCallScreen extends StatefulWidget {
  final String username;
  final bool isVideoEnabled;

  const VideoCallScreen({
    super.key,
    required this.username,
    this.isVideoEnabled = true,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool isMuted = false;
  bool isVideoOn = true;
  bool isScreenSharing = false;

  late Timer _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();

    isVideoOn = widget.isVideoEnabled;

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        setState(() {
          _seconds++;
        });
      },
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get callDuration {
    final hours = _seconds ~/ 3600;
    final minutes = (_seconds % 3600) ~/ 60;
    final seconds = _seconds % 60;

    if (hours > 0) {
      return "${hours.toString().padLeft(2, '0')}:"
          "${minutes.toString().padLeft(2, '0')}:"
          "${seconds.toString().padLeft(2, '0')}";
    }

    return "${minutes.toString().padLeft(2, '0')}:"
        "${seconds.toString().padLeft(2, '0')}";
  }

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
                  CircleAvatar(
                    backgroundColor: Colors.white12,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                      onPressed: () =>
                          Navigator.pop(context),
                    ),
                  ),

                  Column(
                    children: [
                      Text(
                        isVideoOn
                            ? "Video Call"
                            : "Audio Call",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        callDuration,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 45),
                ],
              ),
            ),

            const Spacer(),

            // USER AVATAR

            CircleAvatar(
              radius: 60,
              backgroundColor:
              Colors.grey.shade800,
              child: Text(
                widget.username[0]
                    .toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 45,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              widget.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

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

            // CONTROLS

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
                  _buildButton(
                    icon: isMuted
                        ? Icons.mic_off
                        : Icons.mic,
                    color: isMuted
                        ? Colors.red
                        : Colors.white24,
                    onTap: () {
                      setState(() {
                        isMuted = !isMuted;
                      });
                    },
                  ),

                  _buildButton(
                    icon: isVideoOn
                        ? Icons.videocam
                        : Icons.videocam_off,
                    color: isVideoOn
                        ? Colors.white24
                        : Colors.orange,
                    onTap: () {
                      setState(() {
                        isVideoOn = !isVideoOn;
                      });
                    },
                  ),

                  _buildButton(
                    icon: isScreenSharing
                        ? Icons
                        .stop_screen_share_rounded
                        : Icons
                        .screen_share_rounded,
                    color: isScreenSharing
                        ? Colors.red
                        : Colors.blue,
                    onTap: () {
                      setState(() {
                        isScreenSharing =
                        !isScreenSharing;
                      });
                    },
                  ),

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