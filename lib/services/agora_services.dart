import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraService {
  RtcEngine? engine;

  static const String appId = "5dbf13f2081f431ea118e686cce807d0";

  bool get isInitialized => engine != null;

  /// Request Camera & Microphone Permissions
  Future<bool> requestPermissions() async {
    final status = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    return status[Permission.camera]!.isGranted &&
        status[Permission.microphone]!.isGranted;
  }

  Future<void> initialize({
    required Function() onJoinSuccess,
    required Function(int uid) onUserJoined,
    required Function(int uid) onUserOffline,
    Function(int uid, bool muted)? onUserMuteVideo,
  }) async {
    if (engine != null) return;

    engine = createAgoraRtcEngine();

    await engine!.initialize(
      const RtcEngineContext(
        appId: appId,
      ),
    );

    engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          onJoinSuccess();
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          onUserJoined(remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          onUserOffline(remoteUid);
        },
        onUserMuteVideo: (connection, remoteUid, muted) {
          if (onUserMuteVideo != null) {
            onUserMuteVideo(remoteUid, muted);
          }
        },
      ),
    );

    await engine!.enableVideo();

    await engine!.enableAudio();

    await engine!.startPreview();
  }

  /// Join Channel
  Future<void> joinChannel({
    required String channelId,
    required String token,
    int uid = 0,
  }) async {
    if (engine == null) return;

    await engine!.joinChannel(
      token: token,
      channelId: channelId,
      uid: uid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
  }

  /// Leave Channel
  Future<void> leaveChannel() async {
    if (engine == null) return;

    await engine!.leaveChannel();
  }

  /// Mute / Unmute Microphone
  Future<void> muteMicrophone(bool mute) async {
    if (engine == null) return;

    await engine!.muteLocalAudioStream(mute);
  }

  /// Enable / Disable Camera
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

  /// Start Screen Sharing
  Future<void> startScreenSharing() async {
    if (engine == null) return;

    await engine!.startScreenCapture(
      const ScreenCaptureParameters2(
        captureAudio: true,
        captureVideo: true,
      ),
    );

    await engine!.updateChannelMediaOptions(
      const ChannelMediaOptions(
        publishScreenTrack: true,
        publishCameraTrack: false,
        publishMicrophoneTrack: true,
        publishScreenCaptureAudio: true,
        publishScreenCaptureVideo: true,
      ),
    );
  }

  /// Stop Screen Sharing
  Future<void> stopScreenSharing() async {
    if (engine == null) return;

    await engine!.stopScreenCapture();

    await engine!.updateChannelMediaOptions(
      const ChannelMediaOptions(
        publishScreenTrack: false,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        publishScreenCaptureAudio: false,
        publishScreenCaptureVideo: false,
      ),
    );
  }

  /// Release Engine
  Future<void> dispose() async {
    if (engine == null) return;

    await engine!.leaveChannel();
    await engine!.release();

    engine = null;
  }
}