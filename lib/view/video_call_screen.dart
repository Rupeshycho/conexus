import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../services/agora_services.dart';

class VideoCallScreen extends StatefulWidget {
  final String username;
  final bool isVideoEnabled;
  final String? callId;
  final bool isIncoming;
  final String? receiverId;

  const VideoCallScreen({
    super.key,
    required this.username,
    this.isVideoEnabled = true,
    this.callId,
    this.isIncoming = false,
    this.receiverId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}
class _VideoCallScreenState extends State<VideoCallScreen> {
  /// Agora
  final AgoraService _agora = AgoraService();

  int? _remoteUid;
  bool _joined = false;
  bool _isRemoteVideoMuted = false;

  /// Call Controls
  bool isMuted = false;
  bool isVideoOn = true;
  bool isScreenSharing = false;
  bool _isDisposed = false;
  bool _isEndingCall = false;

  /// Timer
  Timer? _timer;
  int _seconds = 0;

  /// Firestore
  StreamSubscription? _callSubscription;

  /// Call Status
  String _statusText = "";


  @override
  void initState() {
    super.initState();

    isVideoOn = widget.isVideoEnabled;

    _statusText =
    widget.isIncoming
        ? "Connecting..."
        : (isVideoOn ? "Video Calling..." : "Voice Calling...");

    if (widget.callId == null) {
      _startTimer();
    } else {
      _listenToCallStatus();
    }

    _startAgora();
  }

  Future<void> _startAgora() async {
    try {
      final granted = await _agora.requestPermissions();

      if (!granted) {
        debugPrint("Permission denied");
        return;
      }

      await _agora.initialize(
        onJoinSuccess: () {
          if (!mounted || _isDisposed) return;

          setState(() {
            _joined = true;
          });
        },
        onUserJoined: (uid) {
          if (!mounted || _isDisposed) return;

          setState(() {
            _remoteUid = uid;
            _statusText = "Connected";
          });

          if (_timer == null || !_timer!.isActive) {
            _startTimer();
          }
        },
        onUserOffline: (uid) {
          if (!mounted || _isDisposed) return;

          setState(() {
            _remoteUid = null;
          });
        },
        onUserMuteVideo: (uid, muted) {
          if (!mounted || _isDisposed) return;

          setState(() {
            _isRemoteVideoMuted = muted;
          });
        },
      );

      await _agora.joinChannel(
        channelId: widget.callId ?? "room1",
        token: "",
      );
      if (!mounted || _isDisposed) return;
    } catch (e) {
      debugPrint("Agora Error : $e");
    }
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (!mounted || _isDisposed) return;

        setState(() {
          _seconds++;
        });
      },
    );
  }

  String getChatRoomId(String uid1, String uid2) {
    final list = [uid1, uid2];
    list.sort();
    return "${list[0]}_${list[1]}";
  }

  Future<void> _sendCallLogToChat(String status) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (widget.receiverId == null || currentUserId.isEmpty) return;

    final chatRoomId = getChatRoomId(currentUserId, widget.receiverId!);
    final logText = status == 'missed' ? 'Missed Call' : 'Call Ended';
    final now = FieldValue.serverTimestamp();

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add({
      'text': logText,
      'type': 'call',
      'status': 'sent',
      'senderId': currentUserId,
      'receiverId': widget.receiverId,
      'time': now,
    });

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId)
        .update({
      'lastMessage': logText,
      'lastMessageTime': now,
      'lastMessageSenderId': currentUserId,
    });
  }

  void _listenToCallStatus() {
    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen(
          (snapshot) {
        if (!mounted || _isDisposed) return;

        if (!snapshot.exists) {
          _endCallLocally();
          return;
        }

        final data = snapshot.data();
        if (data == null) return;

        final status = data['status'] as String?;

        switch (status) {
          case "connected":
            if (_timer == null || !_timer!.isActive) {
              setState(() {
                _statusText = "Connected";
              });

              _startTimer();
            }
            break;

          case "declined":
            _sendCallLogToChat('missed');
            _handleCallFinished("Call Declined", 2);
            break;

          case "cancelled":
            _sendCallLogToChat('missed');
            _handleCallFinished("Call Cancelled");
            break;

          case "ended":
            _sendCallLogToChat('ended');
            _handleCallFinished("Call Ended");
            break;
        }
      },
      onError: (error) {
        debugPrint("Firestore Listener Error: $error");
      },
    );
  }

  Future<void> _handleCallFinished(String message, [
    int delaySeconds = 1,
  ]) async {
    if (!mounted || _isDisposed) return;

    _timer?.cancel();

    setState(() {
      _statusText = message;
    });

    await Future.delayed(Duration(seconds: delaySeconds));

    if (!mounted || _isDisposed) return;

    await _callSubscription?.cancel();
    await _agora.leaveChannel();

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _endCallLocally() async {
    _timer?.cancel();
    await _callSubscription?.cancel();

    if (!mounted) return;

    Navigator.maybePop(context);
  }

  Future<void> _endCall() async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    try {
      // Stop timer
      _timer?.cancel();

      // Stop Firestore listener
      await _callSubscription?.cancel();

      // Leave Agora channel
      await _agora.leaveChannel();

      // Update Firestore call status
      if (widget.callId != null) {
        final docRef = FirebaseFirestore.instance
            .collection('calls')
            .doc(widget.callId);

        final snapshot = await docRef.get();

        if (snapshot.exists) {
          final status = snapshot.data()?['status'] as String?;

          if (status != 'ended' && status != 'cancelled') {
            final newStatus = status == 'dialing' ? 'cancelled' : 'ended';
            await docRef.update({
              'status': newStatus,
              'endedAt': FieldValue.serverTimestamp(),
            });
            await _sendCallLogToChat(newStatus == 'cancelled' ? 'missed' : 'ended');
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error ending call: $e');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (!mounted || _isDisposed) return;

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _callSubscription?.cancel();
    _agora.dispose();
    _isDisposed = true;
    super.dispose();
  }

  String get callDuration {
    final duration = Duration(seconds: _seconds);

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: WillPopScope(
        onWillPop: () async {
          await _endCall();
          return false;
        },
        child: SafeArea(
          child: Column(
            children: [
              // ===========================
              // Top Bar
              // ===========================
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
                        onPressed: () async {
                          await _endCall();
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
                        const SizedBox(height: 3),
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

              // ===========================
              // Video Area
              // ===========================
              Expanded(
                child: Stack(
                  children: [

                    /// Remote Video
                    Positioned.fill(
                      child: (_agora.isInitialized &&
                          _joined &&
                          _remoteUid != null &&
                          !_isRemoteVideoMuted)
                          ? AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: _agora.engine!,
                          connection: RtcConnection(
                            channelId: widget.callId ?? "room1",
                          ),
                          canvas: VideoCanvas(
                            uid: _remoteUid,
                            renderMode:
                            RenderModeType.renderModeHidden,
                          ),
                        ),
                      )
                          : Container(
                        color: Colors.black87,
                        child: Center(
                          child: Column(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 55,
                                child: Text(
                                  widget.username[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 40),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                widget.username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _isRemoteVideoMuted ? "Camera is off" : _statusText,
                                style: const TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    /// Local Preview
                    Positioned(
                      top: 20,
                      right: 20,
                      width: 120,
                      height: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: isScreenSharing
                            ? Container(
                          color: Colors.blueGrey,
                          child: const Center(
                            child: Icon(
                              Icons.screen_share,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        )
                            : (_agora.isInitialized && _joined && isVideoOn)
                            ? AgoraVideoView(
                          controller: VideoViewController(
                            rtcEngine: _agora.engine!,
                            canvas: const VideoCanvas(
                              uid: 0,
                              renderMode:
                              RenderModeType.renderModeHidden,
                            ),
                          ),
                        )
                            : Container(
                          color: Colors.grey.shade900,
                          child: const Center(
                            child: Icon(
                              Icons.person_outline,
                              color: Colors.white54,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ===========================
              // Bottom Controls
              // ===========================
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 40,
                  left: 20,
                  right: 20,
                  top: 15,
                ),
                child: Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
                  children: [

                    // Mic
                    _buildButton(
                      icon:
                      isMuted ? Icons.mic_off : Icons.mic,
                      color:
                      isMuted ? Colors.red : Colors.white24,
                      onTap: () async {
                        setState(() {
                          isMuted = !isMuted;
                        });

                        await _agora.muteMicrophone(isMuted);
                      },
                    ),

                    // Camera
                    _buildButton(
                      icon: isVideoOn
                          ? Icons.videocam
                          : Icons.videocam_off,
                      color:
                      isVideoOn ? Colors.white24 : Colors.orange,
                      onTap: () async {
                        setState(() {
                          isVideoOn = !isVideoOn;
                          if (_statusText == "Video Calling..." || _statusText == "Voice Calling...") {
                            _statusText = isVideoOn ? "Video Calling..." : "Voice Calling...";
                          }
                        });

                        await _agora.muteCamera(!isVideoOn);
                      },
                    ),

                    // Screen Share
                    _buildButton(
                      icon: isScreenSharing
                          ? Icons.stop_screen_share_rounded
                          : Icons.screen_share_rounded,
                      color:
                      isScreenSharing ? Colors.red : Colors.blue,
                      onTap: () async {
                        setState(() {
                          isScreenSharing = !isScreenSharing;
                        });

                        if (isScreenSharing) {
                          await _agora.startScreenSharing();
                        } else {
                          await _agora.stopScreenSharing();
                        }
                      },
                    ),

                    // End Call
                    _buildButton(
                      icon: Icons.call_end,
                      color: Colors.red,
                      onTap: () async {
                        await _endCall();
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

  bool _buttonBusy = false;

  Widget _buildButton({
    required IconData icon,
    required Color color,
    required Future<void> Function() onTap,
    double size = 65,
    double iconSize = 30,
  }) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: Ink(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _buttonBusy ? color.withOpacity(0.7) : color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          onTap: _buttonBusy
              ? null
              : () async {
            FocusScope.of(context).unfocus();

            setState(() => _buttonBusy = true);

            try {
              await onTap();
            } catch (e, stackTrace) {
              debugPrint('Button Error: $e');
              debugPrintStack(stackTrace: stackTrace);
            } finally {
              if (mounted) {
                setState(() => _buttonBusy = false);
              }
            }
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: _buttonBusy
                ? const SizedBox(
              key: ValueKey('loading'),
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
                : Icon(
              icon,
              key: const ValueKey('icon'),
              color: Colors.white,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}
