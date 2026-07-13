import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin, typed wrapper so callers can catch a single exception type
/// instead of inspecting raw plugin exceptions everywhere.
class AgoraServiceException implements Exception {
  final String message;
  final Object? cause;
  AgoraServiceException(this.message, [this.cause]);

  @override
  String toString() => 'AgoraServiceException: $message';
}

class AgoraService {
  RtcEngine? engine;

  final String appId;

  static const String _defaultAppId =
      "804c1c04968c4ddf8e0fea07ae5d2d21";

  RtcEngineEventHandler? _eventHandler;

  bool _isDisposed = false;
  bool _isInitializing = false;
  bool get hasEngine => engine != null;

  /// Tracks whether the local camera is currently enabled/publishing so
  /// [enableLocalVideo] is idempotent and cheap to call repeatedly (e.g.
  /// a fast double-tap on the camera button), and so [stopScreenSharing]
  /// knows whether to restore the camera track afterwards.
  bool _localVideoEnabled = false;

  /// Guards [rejoinChannel] against overlapping attempts (e.g. a
  /// connection-state callback firing again while a previous rejoin is
  /// still in flight).
  bool _isRejoining = false;

  /// Remembers the last channel/publish settings used to join, so a
  /// dropped connection can be rejoined without the caller having to
  /// resupply them.
  String? _lastChannelId;
  bool _lastPublishVideo = true;

  AgoraService({String? appId}) : appId = appId ?? _defaultAppId {
    assert(
    this.appId.isNotEmpty,
    'AgoraService: no App ID provided. Pass one to the constructor or '
        'build with --dart-define=AGORA_APP_ID=your_app_id.',
    );
  }

  bool get isInitialized => engine != null && !_isDisposed;
  bool get isLocalVideoEnabled => _localVideoEnabled;

  /// Request Camera & Microphone Permissions.
  ///
  /// [needsCamera] should be false for audio-only calls so users aren't
  /// prompted for camera access they don't need.
  Future<bool> requestPermissions({bool needsCamera = true}) async {
    final permissions = <Permission>[
      Permission.microphone,
      if (needsCamera) Permission.camera,
    ];

    final statuses = await permissions.request();

    return statuses.values.every((status) => status.isGranted);
  }

  /// Whether any requested permission was permanently denied (user must
  /// go into system settings to grant it — `request()` won't prompt again).
  Future<bool> isAnyPermissionPermanentlyDenied({bool needsCamera = true}) async {
    final mic = await Permission.microphone.isPermanentlyDenied;
    final cam = needsCamera && await Permission.camera.isPermanentlyDenied;
    return mic || cam;
  }

  /// Initializes the engine and enables audio only. Camera hardware is
  /// deliberately NOT touched here — call [enableLocalVideo] afterwards
  /// for video calls.
  Future<void> initialize({
    required Function() onJoinSuccess,
    required Function(int uid) onUserJoined,
    required Function(int uid) onUserOffline,
    Function(int uid, bool muted)? onUserMuteVideo,
    Function(ErrorCodeType err, String msg)? onError,
    Function(ConnectionStateType state, ConnectionChangedReasonType reason)?
    onConnectionStateChanged,
    Function(QualityType txQuality, QualityType rxQuality)? onNetworkQuality,
    Function()? onTokenWillExpire,
  }) async {

    if (_isInitializing) return;

    if (engine != null) {
      await resetEngine();
    }

    _isDisposed = false;
    _isInitializing = true;

    RtcEngine? newEngine;

    try {
      newEngine = createAgoraRtcEngine();

      await newEngine.initialize(RtcEngineContext(appId: appId));

      if (_isDisposed) {
        await newEngine.release();
        return;
      }

      _eventHandler = RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (_isDisposed) return;
          onJoinSuccess();
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (_isDisposed) return;
          onUserJoined(remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (_isDisposed) return;
          onUserOffline(remoteUid);
        },
        onUserMuteVideo: (connection, remoteUid, muted) {
          if (_isDisposed) return;
          onUserMuteVideo?.call(remoteUid, muted);
        },
        onError: (err, msg) {
          debugPrint("Agora Error: $err — $msg");
          if (!_isDisposed) onError?.call(err, msg);
        },
        onConnectionStateChanged: (connection, state, reason) {
          debugPrint("Agora Connection State: $state, reason: $reason");
          if (!_isDisposed) onConnectionStateChanged?.call(state, reason);
        },
        onNetworkQuality: (connection, remoteUid, txQuality, rxQuality) {
          if (_isDisposed || remoteUid != 0) return;
          onNetworkQuality?.call(txQuality, rxQuality);
        },
        onLocalVideoStateChanged: (source, state, error) {
          debugPrint("Local Video State: $state, error: $error");
        },
        onTokenPrivilegeWillExpire: (connection, token) {
          debugPrint("Agora Token will expire soon — renew token here");
          if (!_isDisposed) onTokenWillExpire?.call();
        },
      );

      newEngine.registerEventHandler(_eventHandler!);

      await newEngine.enableAudio();
      try {
        await newEngine.setAudioProfile(
          profile: AudioProfileType.audioProfileDefault,
          scenario: AudioScenarioType.audioScenarioChatroom,
        );
      } catch (e) {
        debugPrint('AgoraService.initialize: setAudioProfile failed: $e');
      }

      if (_isDisposed) {
        await newEngine.release();
        return;
      }

      engine = newEngine;
    } catch (e, stackTrace) {
      debugPrint('AgoraService.initialize failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      try {
        await newEngine?.release();
      } catch (_) {
        // best-effort cleanup
      }
      engine = null;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }
  Future<void> destroy() async {
    await resetEngine();
  }

  /// Join Channel.
  ///
  /// [publishVideo] controls whether the camera track is published from
  /// the moment of joining. Pass `false` for audio-only calls so no
  /// video is ever offered on the wire.
  ///
  /// Remembers the channel/publish settings used so [rejoinChannel] can
  /// recover from a dropped connection without the caller resupplying
  /// them.
  Future<void> joinChannel({
    required String channelId,
    required String token,
    int uid = 0,
    bool publishVideo = true,
  }) async {
    if (engine == null) {
      throw AgoraServiceException("Engine not initialized");
    }

    try {
      await engine!.leaveChannel();
    } catch (_) {
      // Ignore if not already in a channel.
    }

    _lastChannelId = channelId;
    _lastPublishVideo = publishVideo;

    await engine!.joinChannel(
      token: token,
      channelId: channelId,
      uid: uid,
      options: ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: publishVideo,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
  }

  /// Attempts to rejoin the last-joined channel using the last-known
  /// publish settings. Intended to be called from a
  /// `connectionStateFailed` callback so a call recovers on its own
  /// instead of leaving the user stuck on a dead connection with no
  /// path back in short of manually re-dialing.
  ///
  /// Safe to call repeatedly — overlapping calls are ignored via
  /// [_isRejoining], and it silently no-ops if there's no channel to
  /// rejoin (e.g. the call never joined in the first place).
  Future<bool> rejoinChannel({String token = ""}) async {
    if (_isRejoining) return false;
    if (engine == null || _lastChannelId == null) return false;

    _isRejoining = true;
    try {
      await joinChannel(
        channelId: _lastChannelId!,
        token: token,
        publishVideo: _lastPublishVideo,
      );
      return true;
    } catch (e) {
      debugPrint("AgoraService.rejoinChannel failed: $e");
      return false;
    } finally {
      _isRejoining = false;
    }
  }

  Future<void> resetEngine() async {
    await dispose();

    engine = null;
    _eventHandler = null;
    _localVideoEnabled = false;
    _isInitializing = false;
    _isDisposed = false;
    _lastChannelId = null;
  }

  /// Leave Channel
  Future<void> leaveChannel() async {
    if (engine == null) return;

    try {
      await engine!.leaveChannel();
    } catch (e) {
      debugPrint("LeaveChannel: $e");
    }

    _localVideoEnabled = false;
  }

  /// Mute / Unmute Microphone
  Future<void> muteMicrophone(bool mute) async {
    if (engine == null) return;
    await engine!.muteLocalAudioStream(mute);
  }

  /// Turns the local camera fully on or off — see class docs on the
  /// original implementation for the full rationale.
  Future<void> enableLocalVideo(bool enable) async {
    if (engine == null) return;
    if (enable == _localVideoEnabled) return;

    if (enable) {
      await engine!.enableVideo();
      try {
        await engine!.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 640, height: 360),
            frameRate: 15,
            bitrate: 0,
            orientationMode: OrientationMode.orientationModeAdaptive,
            degradationPreference: DegradationPreference.maintainBalanced,
          ),
        );
      } catch (e) {
        debugPrint('AgoraService.enableLocalVideo: encoder config failed: $e');
      }
      await engine!.startPreview();
      await engine!.muteLocalVideoStream(false);
      await engine!.updateChannelMediaOptions(
        const ChannelMediaOptions(publishCameraTrack: true),
      );
    } else {
      await engine!.muteLocalVideoStream(true);
      await engine!.updateChannelMediaOptions(
        const ChannelMediaOptions(publishCameraTrack: false),
      );
      await engine!.stopPreview();
    }

    _localVideoEnabled = enable;
  }

  /// Low-level camera mute only (does not touch preview or publishing).
  /// Prefer [enableLocalVideo] in almost every case.
  Future<void> muteCamera(bool mute) async {
    if (engine == null) return;
    await engine!.muteLocalVideoStream(mute);
  }

  /// Switch Camera
  Future<void> switchCamera() async {
    if (engine == null) return;
    await engine!.switchCamera();
  }

  /// Speaker
  Future<void> enableSpeaker(bool enable) async {
    if (engine == null) return;
    await engine!.setEnableSpeakerphone(enable);
  }

  /// Call this with a freshly-fetched token from your token server when
  /// [onTokenWillExpire] fires. No-op if the engine hasn't been created.
  Future<void> renewToken(String token) async {
    if (engine == null) return;
    await engine!.renewToken(token);
  }

  /// Start Screen Sharing.
  Future<void> startScreenSharing() async {
    if (engine == null) return;

    await engine!.startScreenCapture(
      const ScreenCaptureParameters2(
        captureAudio: true,
        captureVideo: true,
      ),
    );

    try {
      await engine!.updateChannelMediaOptions(
        const ChannelMediaOptions(
          publishScreenTrack: true,
          publishCameraTrack: false,
          publishMicrophoneTrack: true,
          publishScreenCaptureAudio: true,
          publishScreenCaptureVideo: true,
        ),
      );
    } catch (e) {
      debugPrint('AgoraService.startScreenSharing: failed to switch published '
          'tracks, stopping screen capture. Error: $e');
      try {
        await engine!.stopScreenCapture();
      } catch (_) {
        // best-effort rollback
      }
      rethrow;
    }
  }

  /// Stop Screen Sharing.
  Future<void> stopScreenSharing() async {
    if (engine == null) return;

    await engine!.stopScreenCapture();

    try {
      await engine!.updateChannelMediaOptions(
        ChannelMediaOptions(
          publishScreenTrack: false,
          publishCameraTrack: _localVideoEnabled,
          publishMicrophoneTrack: true,
          publishScreenCaptureAudio: false,
          publishScreenCaptureVideo: false,
        ),
      );
    } catch (e) {
      debugPrint('AgoraService.stopScreenSharing: screen capture stopped but '
          'failed to switch published tracks back. Error: $e');
      rethrow;
    }
  }

  /// Release Engine. Safe to call multiple times.
  Future<void> dispose() async {
    if (engine == null) return;

    try {
      await leaveChannel();

      if (_eventHandler != null) {
        engine!.unregisterEventHandler(_eventHandler!);
        _eventHandler = null;
      }

      await engine!.release(sync: true);
    } catch (e) {
      debugPrint("Dispose Error: $e");
    }

    engine = null;
    _localVideoEnabled = false;
    _isInitializing = false;
    _isDisposed = false;
  }
}
