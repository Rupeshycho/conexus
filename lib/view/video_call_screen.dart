import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import '../services/agora_services.dart';

class VideoCallScreen extends StatefulWidget {
  final String username;
  final bool isVideoEnabled;
  final String? callId;
  final bool isIncoming;
  final String? receiverId;

  final AgoraService? agoraService;

  const VideoCallScreen({
    super.key,
    required this.username,
    this.isVideoEnabled = true,
    this.callId,
    this.isIncoming = false,
    this.receiverId,
    this.agoraService,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> with WidgetsBindingObserver {
  /// Agora
  late final AgoraService _agora;

  int? _remoteUid;
  bool _joined = false;
  bool _isRemoteVideoMuted = false;

  /// Call Controls
  bool isMuted = false;
  bool isVideoOn = true;
  bool isScreenSharing = false;
  bool isSpeakerOn = true;
  bool _isDisposed = false;
  bool _isEndingCall = false;

  bool _engineReady = false;
  bool _isSwitchingCamera = false;
  bool _wasVideoOnBeforeScreenShare = false;

  /// Permission / init error state
  bool _permissionDenied = false;
  bool _permissionPermanentlyDenied = false;
  String? _agoraErrorMessage;

  ConnectionStateType? _connectionState;
  QualityType? _networkQuality;

  bool _isStartingAgora = false;

  /// Auto-retries _startAgora on failure a few times with backoff,
  /// before falling back to a manual Retry banner. Most transient
  /// connection blips resolve on their own within a few seconds — this
  /// means the person doesn't have to notice a failure and tap Retry
  /// for the call to actually go through.
  int _startAgoraRetryCount = 0;
  static const int _maxAutoRetries = 3;
  Timer? _autoRetryTimer;

  /// Guards against overlapping rejoin attempts when the connection
  /// drops mid-call.
  bool _isReconnecting = false;
  Timer? _reconnectDebounce;

  /// Timer
  Timer? _timer;
  int _seconds = 0;

  /// Auto-cancel unanswered outgoing calls after this long
  static const Duration _dialTimeout = Duration(seconds: 45);
  Timer? _dialTimeoutTimer;

  /// Firestore
  StreamSubscription? _callSubscription;

  /// Call Status
  String _statusText = "";

  /// Per-button busy tracking (so one control doesn't disable the others)
  final Set<String> _busyButtons = {};

  String get _displayInitial =>
      widget.username.trim().isNotEmpty ? widget.username.trim()[0].toUpperCase() : "?";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _agora = widget.agoraService ?? AgoraService();

    isVideoOn = widget.isVideoEnabled;
    isSpeakerOn = isVideoOn;

    _statusText = widget.isIncoming
        ? "Connecting..."
        : (isVideoOn ? "Video Calling..." : "Voice Calling...");

    if (widget.callId == null) {
      _startTimer();
    } else {
      _listenToCallStatus();
      if (!widget.isIncoming) {
        _startDialTimeout();
      }
    }

    _startAgora();
  }

  /// Keeps the mic/audio path alive if the app is briefly backgrounded
  /// (e.g. switching to check a notification) instead of the call
  /// silently degrading with no visibility into what changed. Camera
  /// preview is left alone — Agora/the OS already handle pausing that
  /// appropriately when backgrounded.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    if (state == AppLifecycleState.resumed) {
      // Coming back from background is a common moment for a connection
      // to have quietly failed without the user noticing — nudge a
      // reconnect check.
      if (_connectionState == ConnectionStateType.connectionStateFailed) {
        _attemptReconnect();
      }
    }
  }

  void _startDialTimeout() {
    _dialTimeoutTimer?.cancel();
    _dialTimeoutTimer = Timer(_dialTimeout, () async {
      if (!mounted || _isDisposed) return;
      if (_statusText != "Connected") {
        await _sendCallLogToChat('missed');
        await _endCall(finalStatus: 'cancelled');
      }
    });
  }

  Future<void> _startAgora() async {
    if (_isStartingAgora) return;
    _isStartingAgora = true;
    _autoRetryTimer?.cancel();

    try {
      final granted = await _agora.requestPermissions(needsCamera: isVideoOn);

      if (!granted) {
        if (!mounted || _isDisposed) return;
        final permanentlyDenied =
        await _agora.isAnyPermissionPermanentlyDenied(needsCamera: isVideoOn);
        if (!mounted || _isDisposed) return;
        setState(() {
          _permissionDenied = true;
          _permissionPermanentlyDenied = permanentlyDenied;
          _statusText = "Camera/microphone permission needed";
        });
        return;
      }

      await _agora.initialize(
        onJoinSuccess: () {
          if (!mounted || _isDisposed) return;
          setState(() {
            _joined = true;
          });
          // A successful join proves the connection path works —
          // reset the auto-retry counter so a *future* drop gets the
          // full retry budget again instead of inheriting attempts
          // spent on the initial connect.
          _startAgoraRetryCount = 0;
        },
        onUserJoined: (uid) {
          if (!mounted || _isDisposed) return;
          setState(() {
            _remoteUid = uid;
            _statusText = "Connected";
          });
          _dialTimeoutTimer?.cancel();
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
        onError: (err, msg) {
          if (!mounted || _isDisposed) return;
          setState(() {
            _agoraErrorMessage = _friendlyAgoraError(err, msg);
          });
        },
        onConnectionStateChanged: (state, reason) {
          if (!mounted || _isDisposed) return;
          setState(() {
            _connectionState = state;
          });
          // The engine's own reconnect logic handles brief network
          // blips; a genuine "failed" state means it's given up, so
          // this drives its own rejoin attempt rather than leaving the
          // person on a permanently dead call screen.
          if (state == ConnectionStateType.connectionStateFailed) {
            _attemptReconnect();
          } else if (state == ConnectionStateType.connectionStateConnected) {
            _startAgoraRetryCount = 0;
          }
        },
        onNetworkQuality: (txQuality, rxQuality) {
          if (!mounted || _isDisposed) return;
          setState(() {
            _networkQuality = rxQuality;
          });
        },
        onTokenWillExpire: () {
          debugPrint("Agora token expiring soon — renew it here once a "
              "token server is in place.");
        },
      );

      if (!mounted || _isDisposed) return;
      setState(() {
        _engineReady = true;
      });

      await _agora.joinChannel(
        channelId: widget.callId ?? "room1",
        token: "",
        publishVideo: isVideoOn,
      );
      if (!mounted || _isDisposed) return;

      try {
        await _agora.enableSpeaker(isSpeakerOn);
      } catch (e) {
        debugPrint("Error setting initial speaker route: $e");
      }

      try {
        await _agora.enableLocalVideo(isVideoOn);
      } catch (e) {
        debugPrint("Error enabling local video: $e");
        if (mounted && !_isDisposed && isVideoOn) {
          setState(() {
            isVideoOn = false;
            _agoraErrorMessage = "Camera couldn't start — continuing with audio only.";
          });
        }
      }

      // A clean run start-to-finish — clear any stale error banner
      // left over from an earlier failed attempt.
      if (mounted && !_isDisposed && _agoraErrorMessage != null) {
        setState(() => _agoraErrorMessage = null);
      }
    } catch (e) {
      debugPrint("Agora Error : $e");
      if (!mounted || _isDisposed) return;

      if (_startAgoraRetryCount < _maxAutoRetries) {
        _startAgoraRetryCount++;
        final delay = Duration(seconds: _startAgoraRetryCount * 2);
        setState(() {
          _agoraErrorMessage =
          "Connection issue — retrying (${_startAgoraRetryCount}/$_maxAutoRetries)...";
        });
        _autoRetryTimer?.cancel();
        _autoRetryTimer = Timer(delay, () {
          if (!mounted || _isDisposed) return;
          _startAgora();
        });
      } else {
        setState(() {
          _agoraErrorMessage = "Couldn't connect to the call. Please try again.";
        });
      }
    } finally {
      _isStartingAgora = false;
    }
  }

  /// Attempts to rejoin the channel using the engine's own last-known
  /// settings. Debounced so a burst of connection-state callbacks
  /// doesn't fire overlapping rejoin attempts.
  void _attemptReconnect() {
    if (_isReconnecting || !mounted || _isDisposed) return;
    _reconnectDebounce?.cancel();
    _reconnectDebounce = Timer(const Duration(seconds: 2), () async {
      if (!mounted || _isDisposed || _isReconnecting) return;
      _isReconnecting = true;
      try {
        final ok = await _agora.rejoinChannel();
        if (!ok && mounted && !_isDisposed) {
          setState(() {
            _agoraErrorMessage = "Connection lost. Tap Retry to reconnect.";
          });
        }
      } finally {
        _isReconnecting = false;
      }
    });
  }

  String _friendlyAgoraError(ErrorCodeType err, String msg) {
    switch (err) {
      case ErrorCodeType.errTokenExpired:
        return "Session expired. Please try calling again.";
      case ErrorCodeType.errInvalidToken:
        return "Couldn't connect the call (invalid token).";
      case ErrorCodeType.errJoinChannelRejected:
        return "Couldn't join the call. Please try again.";
      case ErrorCodeType.errNoServerResources:
        return "Call servers are busy. Please try again shortly.";
      default:
        return "A call error occurred. Please try again.";
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

    try {
      final chatRoomId = getChatRoomId(currentUserId, widget.receiverId!);
      final logText = status == 'missed' ? 'Missed Call' : 'Call Ended';
      final now = FieldValue.serverTimestamp();

      final chatRoomRef =
      FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId);

      await chatRoomRef.collection('messages').add({
        'text': logText,
        'type': 'call',
        'status': 'sent',
        'senderId': currentUserId,
        'receiverId': widget.receiverId,
        'time': now,
      });

      await chatRoomRef.set({
        'lastMessage': logText,
        'lastMessageTime': now,
        'lastMessageSenderId': currentUserId,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error sending call log: $e");
    }
  }

  void _listenToCallStatus() {
    _callSubscription?.cancel();
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
            _dialTimeoutTimer?.cancel();
            if (_timer == null || !_timer!.isActive) {
              setState(() {
                _statusText = "Connected";
              });
              _startTimer();
            }
            break;

          case "declined":
            _dialTimeoutTimer?.cancel();
            _sendCallLogToChat('missed');
            _handleCallFinished("Call Declined", 2);
            break;

          case "cancelled":
            _dialTimeoutTimer?.cancel();
            _sendCallLogToChat('missed');
            _handleCallFinished("Call Cancelled");
            break;

          case "ended":
            _dialTimeoutTimer?.cancel();
            _sendCallLogToChat('ended');
            _handleCallFinished("Call Ended");
            break;
        }
      },
      onError: (error) {
        debugPrint("Firestore Listener Error: $error");
        // A dropped Firestore listener previously meant this screen
        // would never learn the call had ended/been declined on the
        // other end. Re-subscribe after a short delay instead of
        // leaving the call state permanently stale.
        if (!mounted || _isDisposed) return;
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted || _isDisposed) return;
          _listenToCallStatus();
        });
      },
    );
  }

  Future<void> _handleCallFinished(String message, [int delaySeconds = 1]) async {
    if (!mounted || _isDisposed) return;

    _timer?.cancel();
    _dialTimeoutTimer?.cancel();

    setState(() {
      _statusText = message;
    });

    await Future.delayed(Duration(seconds: delaySeconds));

    if (!mounted || _isDisposed) return;

    await _callSubscription?.cancel();

    if (isScreenSharing) {
      try {
        await _agora.stopScreenSharing();
      } catch (e) {
        debugPrint("Error stopping screen share on call finish: $e");
      }
    }

    await _agora.destroy();

    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _endCallLocally() async {
    _timer?.cancel();
    _dialTimeoutTimer?.cancel();
    await _callSubscription?.cancel();

    if (!mounted) return;
    Navigator.maybePop(context);
  }

  Future<void> _endCall({String? finalStatus}) async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    try {
      _timer?.cancel();
      _dialTimeoutTimer?.cancel();
      _autoRetryTimer?.cancel();
      _reconnectDebounce?.cancel();

      await _callSubscription?.cancel();

      if (isScreenSharing) {
        try {
          await _agora.stopScreenSharing();
        } catch (e) {
          debugPrint("Error stopping screen share on end call: $e");
        }
      }

      await _agora.resetEngine();

      if (widget.callId != null) {
        final docRef =
        FirebaseFirestore.instance.collection('calls').doc(widget.callId);

        final snapshot = await docRef.get();

        if (snapshot.exists) {
          final status = snapshot.data()?['status'] as String?;

          if (status != 'ended' && status != 'cancelled') {
            final newStatus =
                finalStatus ?? (status == 'dialing' ? 'cancelled' : 'ended');
            await docRef.update({
              'status': newStatus,
              'endedAt': FieldValue.serverTimestamp(),
            });
            await _sendCallLogToChat(newStatus == 'cancelled' ? 'missed' : 'ended');
          }
        } else {
          await _sendCallLogToChat(finalStatus == 'cancelled' ? 'missed' : 'ended');
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
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _dialTimeoutTimer?.cancel();
    _autoRetryTimer?.cancel();
    _reconnectDebounce?.cancel();
    _callSubscription?.cancel();
    if (isScreenSharing) {
      _agora.stopScreenSharing();
    }
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
    final connectionBanner = _buildConnectionBanner();
    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _endCall();
        },
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(child: _buildVideoArea()),
              if (connectionBanner != null) connectionBanner,
              if (_agoraErrorMessage != null) _buildErrorBanner(_agoraErrorMessage!),
              if (_permissionDenied) _buildPermissionBanner(),
              if (isScreenSharing) _buildScreenShareBanner(),
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================
  // Top Bar
  // ===========================
  Widget _buildTopBar() {
    final qualityIcon = _buildNetworkQualityIcon();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(
            backgroundColor: Colors.white12,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () async {
                await _endCall();
              },
            ),
          ),
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isVideoOn ? "Video Call" : "Audio Call",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (qualityIcon != null) ...[
                    const SizedBox(width: 6),
                    qualityIcon,
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                callDuration,
                style: const TextStyle(color: Colors.greenAccent, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(width: 45),
        ],
      ),
    );
  }

  Widget? _buildNetworkQualityIcon() {
    final quality = _networkQuality;
    if (quality == null) return null;

    IconData icon;
    Color color;
    switch (quality) {
      case QualityType.qualityExcellent:
      case QualityType.qualityGood:
        icon = Icons.signal_cellular_alt;
        color = Colors.greenAccent;
        break;
      case QualityType.qualityPoor:
        icon = Icons.signal_cellular_alt_2_bar;
        color = Colors.orangeAccent;
        break;
      case QualityType.qualityBad:
      case QualityType.qualityVbad:
        icon = Icons.signal_cellular_alt_1_bar;
        color = Colors.redAccent;
        break;
      case QualityType.qualityDown:
        icon = Icons.signal_cellular_connected_no_internet_0_bar;
        color = Colors.redAccent;
        break;
      default:
        return null;
    }
    return Icon(icon, color: color, size: 16);
  }

  Widget? _buildConnectionBanner() {
    final state = _connectionState;
    if (state == null) return null;

    String text;
    Color color;
    switch (state) {
      case ConnectionStateType.connectionStateReconnecting:
        text = "Reconnecting...";
        color = Colors.orangeAccent;
        break;
      case ConnectionStateType.connectionStateFailed:
        text = _isReconnecting ? "Reconnecting..." : "Connection lost";
        color = Colors.redAccent;
        break;
      default:
        return null;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ===========================
  // Video Area
  // ===========================
  Widget _buildVideoArea() {
    return Stack(
      children: [
        Positioned.fill(
          child: (_agora.isInitialized &&
              _joined &&
              _remoteUid != null &&
              !_isRemoteVideoMuted)
              ? AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _agora.engine!,
              connection: RtcConnection(channelId: widget.callId ?? "room1"),
              canvas: VideoCanvas(
                uid: _remoteUid,
                renderMode: RenderModeType.renderModeHidden,
              ),
            ),
          )
              : Container(
            color: Colors.black87,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 55,
                    child: Text(
                      _displayInitial,
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.username.trim().isNotEmpty ? widget.username : "Unknown",
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isRemoteVideoMuted ? "Camera is off" : _statusText,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          top: 20,
          right: 20,
          width: 120,
          height: 180,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isScreenSharing
                    ? Container(
                  color: Colors.blueGrey,
                  child: const Center(
                    child: Icon(Icons.screen_share, color: Colors.white, size: 40),
                  ),
                )
                    : (_agora.isInitialized && isVideoOn)
                    ? AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _agora.engine!,
                    canvas: const VideoCanvas(
                      uid: 0,
                      renderMode: RenderModeType.renderModeHidden,
                    ),
                  ),
                )
                    : Container(
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Icon(Icons.person_outline, color: Colors.white54, size: 30),
                  ),
                ),
              ),

              if (isVideoOn && !isScreenSharing && _engineReady)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: _isSwitchingCamera
                        ? null
                        : () async {
                      setState(() => _isSwitchingCamera = true);
                      try {
                        await _agora.switchCamera();
                      } catch (e) {
                        debugPrint("Error switching camera: $e");
                      } finally {
                        if (mounted) setState(() => _isSwitchingCamera = false);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: _isSwitchingCamera
                          ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),

              if (isMuted)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_off, color: Colors.redAccent, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          TextButton(
            onPressed: _isStartingAgora
                ? null
                : () async {
              _autoRetryTimer?.cancel();
              _startAgoraRetryCount = 0;
              setState(() {
                _agoraErrorMessage = null;
              });
              await _startAgora();
            },
            child: _isStartingAgora
                ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orangeAccent),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_off, color: Colors.orangeAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _permissionPermanentlyDenied
                  ? "Camera & microphone access was denied. Enable it in Settings to continue."
                  : "Camera & microphone access is required for calls.",
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _isStartingAgora
                ? null
                : () async {
              if (_permissionPermanentlyDenied) {
                await openAppSettings();
                return;
              }
              setState(() {
                _permissionDenied = false;
              });
              await _startAgora();
            },
            child: _isStartingAgora
                ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Text(_permissionPermanentlyDenied ? "Open Settings" : "Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenShareBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueAccent),
      ),
      child: const Row(
        children: [
          Icon(Icons.screen_share, color: Colors.blueAccent, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "You're sharing your screen",
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================
  // Bottom Controls
  // ===========================
  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40, left: 20, right: 20, top: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildButton(
            buttonKey: 'mic',
            icon: isMuted ? Icons.mic_off : Icons.mic,
            color: isMuted ? Colors.red : Colors.white24,
            enabled: _engineReady,
            onTap: () async {
              final next = !isMuted;
              setState(() => isMuted = next);
              try {
                await _agora.muteMicrophone(next);
              } catch (e) {
                if (mounted) setState(() => isMuted = !next);
                rethrow;
              }
            },
          ),

          _buildButton(
            buttonKey: 'speaker',
            icon: isSpeakerOn ? Icons.volume_up : Icons.hearing,
            color: isSpeakerOn ? Colors.blueAccent : Colors.white24,
            enabled: _engineReady,
            onTap: () async {
              final next = !isSpeakerOn;
              setState(() => isSpeakerOn = next);
              try {
                await _agora.enableSpeaker(next);
              } catch (e) {
                if (mounted) setState(() => isSpeakerOn = !next);
                rethrow;
              }
            },
          ),

          _buildButton(
            buttonKey: 'camera',
            icon: isVideoOn ? Icons.videocam : Icons.videocam_off,
            color: isScreenSharing
                ? Colors.white10
                : (isVideoOn ? Colors.white24 : Colors.orange),
            enabled: _engineReady,
            onTap: () async {
              if (isScreenSharing) return;
              final next = !isVideoOn;

              if (next) {
                final granted = await _agora.requestPermissions(needsCamera: true);
                if (!granted) {
                  if (!mounted) return;
                  final permanentlyDenied = await _agora
                      .isAnyPermissionPermanentlyDenied(needsCamera: true);
                  setState(() {
                    _permissionDenied = true;
                    _permissionPermanentlyDenied = permanentlyDenied;
                  });
                  return;
                }
              }

              await _agora.enableLocalVideo(next);

              if (!mounted) return;
              setState(() {
                isVideoOn = next;
                if (_statusText == "Video Calling..." || _statusText == "Voice Calling...") {
                  _statusText = isVideoOn ? "Video Calling..." : "Voice Calling...";
                }
              });
            },
          ),

          _buildButton(
            buttonKey: 'share',
            icon: isScreenSharing
                ? Icons.stop_screen_share_rounded
                : Icons.screen_share_rounded,
            color: isScreenSharing ? Colors.red : Colors.blue,
            enabled: _engineReady,
            onTap: () async {
              if (!isScreenSharing) {
                _wasVideoOnBeforeScreenShare = isVideoOn;
                try {
                  if (isVideoOn) {
                    await _agora.enableLocalVideo(false);
                  }
                  await _agora.startScreenSharing();
                  if (mounted) {
                    setState(() {
                      isScreenSharing = true;
                      isVideoOn = false;
                    });
                  }
                } catch (e) {
                  if (_wasVideoOnBeforeScreenShare) {
                    try {
                      await _agora.enableLocalVideo(true);
                    } catch (_) {
                      // best-effort
                    }
                  }
                  rethrow;
                }
              } else {
                try {
                  await _agora.stopScreenSharing();
                  if (_wasVideoOnBeforeScreenShare) {
                    await _agora.enableLocalVideo(true);
                  }
                  if (mounted) {
                    setState(() {
                      isScreenSharing = false;
                      isVideoOn = _wasVideoOnBeforeScreenShare;
                    });
                  }
                } catch (e) {
                  if (mounted) setState(() => isScreenSharing = false);
                  rethrow;
                }
              }
            },
          ),

          _buildButton(
            buttonKey: 'end',
            icon: Icons.call_end,
            color: Colors.red,
            onTap: () async {
              await _endCall();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String buttonKey,
    required IconData icon,
    required Color color,
    required Future<void> Function() onTap,
    double size = 58,
    double iconSize = 26,
    bool enabled = true,
  }) {
    final isBusy = _busyButtons.contains(buttonKey);
    final effectiveColor =
    !enabled ? color.withOpacity(0.35) : (isBusy ? color.withOpacity(0.7) : color);

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: Ink(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: effectiveColor,
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
          onTap: (isBusy || !enabled)
              ? null
              : () async {
            FocusScope.of(context).unfocus();
            setState(() => _busyButtons.add(buttonKey));

            try {
              await onTap();
            } catch (e, stackTrace) {
              debugPrint('Button "$buttonKey" error: $e');
              debugPrintStack(stackTrace: stackTrace);
            } finally {
              if (mounted) {
                setState(() => _busyButtons.remove(buttonKey));
              }
            }
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: isBusy
                ? const SizedBox(
              key: ValueKey('loading'),
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
                : Icon(icon, key: const ValueKey('icon'), color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }
}
