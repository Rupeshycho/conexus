import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoCallScreen extends StatefulWidget {
  final String username;
  final bool isVideoEnabled;
  final String? callId;
  final bool isIncoming;

  const VideoCallScreen({
    super.key,
    required this.username,
    this.isVideoEnabled = true,
    this.callId,
    this.isIncoming = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool isMuted = false;
  bool isVideoOn = true;
  bool isScreenSharing = false;

  Timer? _timer;
  int _seconds = 0;
  StreamSubscription? _callSubscription;
  String _statusText = "";

  @override
  void initState() {
    super.initState();
    isVideoOn = widget.isVideoEnabled;
    _statusText = widget.isVideoEnabled ? "Video Calling..." : "Voice Calling...";

    if (widget.callId == null) {
      // Mock/test mode - start timer immediately
      _startTimer();
    } else {
      // Live calling mode
      if (widget.isIncoming) {
        // If we are accepting, we are connected immediately
        _statusText = "Connected";
        _startTimer();
      } else {
        // Outgoing call - wait for receiver to accept
        _statusText = widget.isVideoEnabled ? "Video Calling..." : "Voice Calling...";
      }
      _listenToCallStatus();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (mounted) {
          setState(() {
            _seconds++;
          });
        }
      },
    );
  }

  void _listenToCallStatus() {
    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        _endCallLocally();
        return;
      }
      final data = snapshot.data();
      if (data == null) return;

      final status = data['status'] as String?;
      if (!mounted) return;

      if (status == 'connected') {
        if (_timer == null) {
          setState(() {
            _statusText = "Connected";
          });
          _startTimer();
        }
      } else if (status == 'declined') {
        setState(() {
          _statusText = "Call Declined";
        });
        _timer?.cancel();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.maybePop(context);
        });
      } else if (status == 'cancelled') {
        setState(() {
          _statusText = "Call Cancelled";
        });
        _timer?.cancel();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.maybePop(context);
        });
      } else if (status == 'ended') {
        setState(() {
          _statusText = "Call Ended";
        });
        _timer?.cancel();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.maybePop(context);
        });
      }
    });
  }

  void _endCallLocally() {
    _timer?.cancel();
    _callSubscription?.cancel();
    if (mounted) Navigator.maybePop(context);
  }

  void _endCall() async {
    if (widget.callId != null) {
      try {
        final docRef = FirebaseFirestore.instance.collection('calls').doc(widget.callId);
        final snapshot = await docRef.get();
        if (snapshot.exists) {
          final data = snapshot.data();
          final currentStatus = data?['status'] as String?;
          if (currentStatus == 'dialing') {
            await docRef.update({'status': 'cancelled'});
          } else {
            await docRef.update({'status': 'ended'});
          }
        }
      } catch (e) {
        debugPrint("Error updating call status in Firestore: $e");
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _callSubscription?.cancel();
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
      body: WillPopScope(
        onWillPop: () async {
          _endCall();
          return true;
        },
        child: SafeArea(
          child: Column(
            children: [
              // TOP BAR
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white12,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          _endCall();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          isVideoOn ? "Video Call" : "Audio Call",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
              Text(
                widget.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _statusText,
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildButton(
                      icon: isMuted ? Icons.mic_off : Icons.mic,
                      color: isMuted ? Colors.red : Colors.white24,
                      onTap: () {
                        setState(() {
                          isMuted = !isMuted;
                        });
                      },
                    ),
                    _buildButton(
                      icon: isVideoOn ? Icons.videocam : Icons.videocam_off,
                      color: isVideoOn ? Colors.white24 : Colors.orange,
                      onTap: () {
                        setState(() {
                          isVideoOn = !isVideoOn;
                          if (_statusText.contains("Calling")) {
                            _statusText = isVideoOn ? "Video Calling..." : "Voice Calling...";
                          }
                        });
                      },
                    ),
                    _buildButton(
                      icon: isScreenSharing
                          ? Icons.stop_screen_share_rounded
                          : Icons.screen_share_rounded,
                      color: isScreenSharing ? Colors.red : Colors.blue,
                      onTap: () {
                        setState(() {
                          isScreenSharing = !isScreenSharing;
                        });
                      },
                    ),
                    _buildButton(
                      icon: Icons.call_end,
                      color: Colors.red,
                      onTap: () {
                        _endCall();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
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