import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/notification_service.dart';
import 'video_call_screen.dart';

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

  // FIX: when the OS-notification Accept/Decline action resolves a call
  // (handled in NotificationService, in a different isolate/code path
  // than this dialog's own Accept/Decline buttons), it writes the same
  // Firestore status change that this dialog's own `_listenToCallStatus`
  // listener is watching for. Without this marker, both sides would race
  // to pop the navigator: NotificationService pops the dialog and pushes
  // VideoCallScreen, then a moment later this dialog's listener sees the
  // same status change and pops *again* — tearing down the VideoCallScreen
  // that was just pushed. This static set lets NotificationService tell
  // any live dialog instance "I've already handled this call, stand down"
  // before it makes its own navigation change.
  static final Set<String> _externallyResolvedCallIds = {};

  static void markResolvedExternally(String callId) {
    _externallyResolvedCallIds.add(callId);
  }

  static void clearExternallyResolvedMarkers() {
    _externallyResolvedCallIds.clear();
  }

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog> {
  StreamSubscription? _callSubscription;

  bool _isResolved = false;
  bool _isProcessing = false;
  String? _errorMessage;

  /// How many times _acceptCall has auto-retried after a failed write,
  /// so a person on a flaky connection doesn't have to keep mashing
  /// Accept manually for a call that would succeed on its own a moment
  /// later.
  int _acceptRetryCount = 0;
  static const int _maxAcceptRetries = 2;
  Timer? _acceptRetryTimer;

  @override
  void initState() {
    super.initState();
    _listenToCallStatus();
  }

  void _listenToCallStatus() {
    _callSubscription?.cancel();
    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen(
          (snapshot) {
        if (_isResolved) return;

        // FIX: someone else (the OS-notification action handler, running
        // outside this widget) already resolved this call and is handling
        // navigation itself. Stand down instead of also popping — see the
        // comment on `_externallyResolvedCallIds` above for why this
        // matters.
        if (IncomingCallDialog._externallyResolvedCallIds.contains(widget.callId)) {
          _isResolved = true;
          _callSubscription?.cancel();
          return;
        }

        if (!snapshot.exists) {
          _dismissDialog();
          return;
        }

        final data = snapshot.data();
        if (data == null) return;

        final status = data['status'] as String?;
        if (status == 'cancelled' ||
            status == 'ended' ||
            status == 'declined' ||
            status == 'connected') {
          _dismissDialog();
        }
      },
      onError: (error) {
        debugPrint("Firestore Listener Error: $error");
        // Keep tracking the call rather than going silent — otherwise a
        // caller hanging up mid-error leaves this dialog stuck open
        // indefinitely.
        if (_isResolved) return;
        Future.delayed(const Duration(seconds: 2), () {
          if (_isResolved) return;
          _listenToCallStatus();
        });
      },
    );
  }

  void _dismissDialog() {
    if (_isResolved) return;
    _isResolved = true;

    _acceptRetryTimer?.cancel();
    _callSubscription?.cancel();

    final navigator = NotificationService.navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _declineCall() async {
    if (_isResolved || _isProcessing) return;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    await _callSubscription?.cancel();

    try {
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(widget.callId)
          .update({'status': 'declined'});
    } catch (e) {
      debugPrint("Error declining call: $e");
      // Decline still closes the dialog locally even if the write
      // failed to sync — this device shouldn't be stuck on a dead call
      // just because one write didn't land.
    }

    _dismissDialog();
  }

  Future<void> _acceptCall({bool isRetry = false}) async {
    if (_isResolved) return;
    if (!isRetry && _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = isRetry ? _errorMessage : null;
    });

    await _callSubscription?.cancel();

    try {
      // FIX: previously a bare `.update({'status': 'connected'})` —
      // unlike NotificationService's OS-notification Accept path, which
      // uses a transaction that only writes 'connected' if the call is
      // still 'dialing'. Without that same check here, if the caller
      // cancels/hangs up in the moment right before this button is
      // tapped (Firestore update for that hasn't reached this device
      // yet), this write would blindly flip status back to 'connected'
      // and revive/rejoin a call the caller already left. Mirror the
      // notification path's joinability check so both Accept paths
      // behave identically.
      final docRef = FirebaseFirestore.instance.collection('calls').doc(widget.callId);
      bool joinable = false;
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final currentStatus = snapshot.data()?['status'] as String?;
        if (!snapshot.exists || currentStatus != 'dialing') {
          return;
        }
        transaction.update(docRef, {'status': 'connected'});
        joinable = true;
      });

      if (!joinable) {
        debugPrint("Call ${widget.callId} is no longer joinable");
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _errorMessage = "This call has ended.";
        });
        // The call is already over — dismiss rather than leaving the
        // dialog sitting on a stale Accept/Decline pair.
        _dismissDialog();
        return;
      }

      _isResolved = true;
      _acceptRetryCount = 0;

      // FIX: previously this popped the dialog via
      // `Navigator.of(context, rootNavigator: true)` and then pushed
      // VideoCallScreen using that same *dialog-owned* `context` —
      // but popping the dialog can tear down that context (its State
      // is disposed once the route is removed), so the follow-up push
      // would occasionally silently fail to navigate anywhere. Using
      // the app's global navigator key for BOTH the pop and the push
      // avoids depending on this widget's own context lifecycle at all.
      final navigator = NotificationService.navigatorKey.currentState;
      if (navigator == null) return;

      if (navigator.canPop()) {
        navigator.pop();
      }

      navigator.push(
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
    } catch (e) {
      debugPrint("Error accepting call: $e");

      if (!_isResolved) {
        _listenToCallStatus();
      }

      if (!mounted) return;

      // Auto-retry a couple of times with a short backoff before
      // asking the person to tap Accept again themselves — most
      // failures here are a brief network hiccup on an otherwise-live
      // call.
      if (_acceptRetryCount < _maxAcceptRetries) {
        _acceptRetryCount++;
        setState(() {
          _errorMessage = "Connecting... retrying";
        });
        _acceptRetryTimer?.cancel();
        _acceptRetryTimer = Timer(Duration(seconds: _acceptRetryCount * 2), () {
          if (!mounted || _isResolved) return;
          _acceptCall(isRetry: true);
        });
      } else {
        setState(() {
          _isProcessing = false;
          _errorMessage = "Couldn't answer the call. Check your connection and try again.";
        });
      }
    }
  }

  @override
  void dispose() {
    _acceptRetryTimer?.cancel();
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
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

              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orange.withOpacity(0.08),
                      ),
                    )
                        .animate(onPlay: (controller) => controller.repeat(reverse: true))
                        .scale(
                      begin: const Offset(1.0, 1.0),
                      end: const Offset(1.25, 1.25),
                      duration: 1200.ms,
                    ),
                    Container(
                      width: 115,
                      height: 115,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orange.withOpacity(0.12),
                      ),
                    )
                        .animate(onPlay: (controller) => controller.repeat(reverse: true))
                        .scale(
                      begin: const Offset(1.0, 1.0),
                      end: const Offset(1.15, 1.15),
                      duration: 1200.ms,
                      delay: 200.ms,
                    ),

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
                widget.callerName.trim().isNotEmpty ? widget.callerName : "Unknown",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                widget.isVideo ? "Incoming video request..." : "Incoming audio request...",
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],

              const SizedBox(height: 36),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallActionButton(
                    icon: Icons.call_end,
                    label: "Decline",
                    color: Colors.red,
                    isBusy: _isProcessing,
                    onTap: _declineCall,
                  ),
                  _CallActionButton(
                    icon: widget.isVideo ? Icons.videocam : Icons.phone,
                    label: "Accept",
                    color: Colors.green,
                    isBusy: _isProcessing,
                    onTap: _acceptCall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isBusy;
  final Future<void> Function() onTap;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: isBusy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isBusy ? color.withOpacity(0.5) : color,
              shape: BoxShape.circle,
            ),
            child: isBusy
                ? const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
                : Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
      ],
    );
  }
}
