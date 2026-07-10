import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'video_call_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class IncomingCallDialog extends StatefulWidget {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerImage;
  final bool isVideo;

  const IncomingCallDialog({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerImage,
    required this.isVideo,
  });

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog> {
  StreamSubscription? _callSubscription;

  @override
  void initState() {
    super.initState();
    _listenToCallStatus();
  }

  void _listenToCallStatus() {
    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        _dismissDialog();
        return;
      }
      final data = snapshot.data();
      if (data == null) return;

      final status = data['status'] as String?;
      if (status == 'cancelled' || status == 'ended') {
        _dismissDialog();
      }
    });
  }

  void _dismissDialog() {
    _callSubscription?.cancel();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _declineCall() async {
    try {
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(widget.callId)
          .update({'status': 'declined'});
    } catch (e) {
      debugPrint("Error declining call: $e");
    }
    _dismissDialog();
  }

  void _acceptCall() async {
    try {
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(widget.callId)
          .update({'status': 'connected'});
      
      _callSubscription?.cancel();
      
      if (mounted) {
        // Pop the dialog
        Navigator.of(context, rootNavigator: true).pop();
        
        // Push the call screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoCallScreen(
              username: widget.callerName,
              isVideoEnabled: widget.isVideo,
              callId: widget.callId,
              isIncoming: true,
              receiverId: widget.callerId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error accepting call: $e");
      _dismissDialog();
    }
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isVideo ? "Incoming Video Call" : "Incoming Voice Call",
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 24),
            
            // Pulsing Avatar using flutter_animate
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glowing rings
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange.withOpacity(0.08),
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.25, 1.25), duration: 1200.ms),
                  Container(
                    width: 115,
                    height: 115,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange.withOpacity(0.12),
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.15, 1.15), duration: 1200.ms, delay: 200.ms),
                  
                  // Actual Avatar
                  CircleAvatar(
                    radius: 45,
                    backgroundImage: widget.callerImage.isNotEmpty
                        ? NetworkImage(widget.callerImage)
                        : null,
                    backgroundColor: Colors.grey[800],
                    child: widget.callerImage.isEmpty
                        ? const Icon(Icons.person, size: 45, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            Text(
              widget.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isVideo ? "Incoming video request..." : "Incoming audio request...",
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 36),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Decline Button
                Column(
                  children: [
                    GestureDetector(
                      onTap: _declineCall,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Decline",
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
                
                // Accept Button
                Column(
                  children: [
                    GestureDetector(
                      onTap: _acceptCall,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isVideo ? Icons.videocam : Icons.phone,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Accept",
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
