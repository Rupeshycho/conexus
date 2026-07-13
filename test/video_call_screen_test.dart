import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:conexus/view/video_call_screen.dart';
import 'package:conexus/services/agora_services.dart';

/// Test double for AgoraService.
///
/// Overrides every method VideoCallScreen actually calls, but keeps each
/// one a safe no-op:
///  - `requestPermissions` / `isAnyPermissionPermanentlyDenied` would
///    otherwise call into permission_handler, which has no platform
///    implementation in a widget test.
///  - `initialize` would otherwise build a real RtcEngine via
///    `createAgoraRtcEngine()` — a platform channel call.
///  - `joinChannel` on the real service throws a StateError when
///    `engine == null` (by design, to catch misuse) — this fake never
///    sets `engine`, so it must override joinChannel to avoid that.
///
/// Everything else the widget calls on `_agora` — `muteMicrophone`,
/// `enableSpeaker`, `enableLocalVideo`, `switchCamera`,
/// `startScreenSharing`, `stopScreenSharing`, `rejoinChannel`,
/// `resetEngine`, `destroy`, `dispose` — is safe to inherit unmodified:
/// each guards on `if (engine == null) return;` (or equivalent) before
/// touching the engine, and this fake never sets `engine`. `isInitialized`
/// (`engine != null && !_isDisposed`) is likewise inherited as-is and
/// correctly reports `false` throughout every test below.
class FakeAgoraService extends AgoraService {
  /// Flip these before pumping the widget to exercise the
  /// permission-denied / permanently-denied banners.
  bool grantPermissions = true;
  bool permissionsPermanentlyDenied = false;

  /// Flip before pumping to exercise the auto-retry -> terminal error
  /// banner path.
  bool throwOnJoinChannel = false;

  int joinChannelCallCount = 0;
  int muteMicrophoneCallCount = 0;
  int enableSpeakerCallCount = 0;
  int switchCameraCallCount = 0;
  int startScreenSharingCallCount = 0;
  int stopScreenSharingCallCount = 0;

  @override
  Future<bool> requestPermissions({bool needsCamera = true}) async =>
      grantPermissions;

  @override
  Future<bool> isAnyPermissionPermanentlyDenied({bool needsCamera = true}) async =>
      permissionsPermanentlyDenied;

  @override
  Future<void> initialize({
    required Function() onJoinSuccess,
    required Function(int uid) onUserJoined,
    required Function(int uid) onUserOffline,
    Function(int uid, bool muted)? onUserMuteVideo,
    Function(ErrorCodeType err, String msg)? onError,
    Function(ConnectionStateType state, ConnectionChangedReasonType reason)?
    onConnectionStateChanged,
    Function(QualityType tx, QualityType rx)? onNetworkQuality,
    Function()? onTokenWillExpire,
  }) async {
    // No-op: intentionally never sets `engine`, so `isInitialized` stays
    // false and every other inherited method's engine-null guard keeps
    // them safe to call without further overrides.
  }

  @override
  Future<void> joinChannel({
    required String channelId,
    required String token,
    bool publishVideo = true,
    int uid = 0,
  }) async {
    joinChannelCallCount++;
    if (throwOnJoinChannel) {
      throw Exception('fake joinChannel failure');
    }
  }

  @override
  Future<void> muteMicrophone(bool muted) async {
    muteMicrophoneCallCount++;
  }

  @override
  Future<void> enableSpeaker(bool enabled) async {
    enableSpeakerCallCount++;
  }

  @override
  Future<void> switchCamera() async {
    switchCameraCallCount++;
  }

  @override
  Future<void> startScreenSharing() async {
    startScreenSharingCallCount++;
  }

  @override
  Future<void> stopScreenSharing() async {
    stopScreenSharingCallCount++;
  }
}

/// Replaces the pumped widget with an empty one so VideoCallScreen's
/// dispose() runs and cancels its periodic call-duration Timer (and any
/// pending auto-retry Timer). Without this, flutter_test fails each test
/// with "A Timer is still pending even after the widget tree was
/// disposed."
Future<void> disposeWidget(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

/// Pumps enough frames for `_startAgora()`'s awaited chain
/// (requestPermissions -> initialize -> setState -> joinChannel ->
/// enableSpeaker -> enableLocalVideo) to fully settle. Each `await`
/// yields at least one microtask, so a handful of small pumps is more
/// reliable than assuming a single pump is enough. Deliberately avoids
/// pumpAndSettle: initState also starts a periodic 1s Timer for call
/// duration, which never "settles".
Future<void> pumpStartAgora(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump(const Duration(milliseconds: 10));
}

void main() {
  group('VideoCallScreen', () {
    late FakeAgoraService fakeAgora;

    setUp(() {
      fakeAgora = FakeAgoraService();
    });

    testWidgets('renders caller details and toggles mic/camera/screen-share',
            (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: VideoCallScreen(
                username: 'ujwal',
                isVideoEnabled: true,
                // Injected so initState's _startAgora() never hits a real
                // platform channel (which would throw MissingPluginException
                // in a widget test and leave _engineReady stuck at false).
                agoraService: fakeAgora,
              ),
            ),
          );
          await pumpStartAgora(tester);

          expect(find.text('ujwal'), findsOneWidget);
          expect(find.text('Video Call'), findsOneWidget);
          expect(find.text('Video Calling...'), findsOneWidget);
          expect(fakeAgora.joinChannelCallCount, 1);

          // Mic starts unmuted.
          expect(find.byIcon(Icons.mic), findsOneWidget);

          await tester.tap(find.byIcon(Icons.mic));
          await tester.pump(); // rebuild with isMuted = true
          await tester.pump(); // let muteMicrophone()'s await resolve

          expect(fakeAgora.muteMicrophoneCallCount, 1);
          // Appears twice by design: once on the mic control button, once as
          // the small local-mute badge overlaid on the local video preview
          // (see the `if (isMuted)` block in _buildVideoArea()).
          expect(find.byIcon(Icons.mic_off), findsNWidgets(2));

          // Turn the camera off.
          expect(find.byIcon(Icons.videocam), findsOneWidget);
          await tester.tap(find.byIcon(Icons.videocam));
          await tester.pump();
          await tester.pump();

          expect(find.text('Audio Call'), findsOneWidget);
          expect(find.text('Voice Calling...'), findsOneWidget);
          expect(find.byIcon(Icons.videocam_off), findsOneWidget);

          // Start screen sharing.
          expect(find.byIcon(Icons.screen_share_rounded), findsOneWidget);
          await tester.tap(find.byIcon(Icons.screen_share_rounded));
          await tester.pump();
          await tester.pump();

          expect(fakeAgora.startScreenSharingCallCount, 1);
          expect(find.byIcon(Icons.stop_screen_share_rounded), findsOneWidget);
          expect(find.text("You're sharing your screen"), findsOneWidget);

          // Stop screen sharing again.
          await tester.tap(find.byIcon(Icons.stop_screen_share_rounded));
          await tester.pump();
          await tester.pump();

          expect(fakeAgora.stopScreenSharingCallCount, 1);
          expect(find.byIcon(Icons.screen_share_rounded), findsOneWidget);
          expect(find.text("You're sharing your screen"), findsNothing);

          await disposeWidget(tester);
        });

    testWidgets('shows "Voice Calling..." for an outgoing audio call',
            (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: VideoCallScreen(
                username: 'priya',
                isVideoEnabled: false,
                agoraService: fakeAgora,
              ),
            ),
          );
          await pumpStartAgora(tester);

          expect(find.text('Audio Call'), findsOneWidget);
          expect(find.text('Voice Calling...'), findsOneWidget);
          // Speaker mirrors isVideoOn at start, so it should render as off.
          expect(find.byIcon(Icons.hearing), findsOneWidget);

          await disposeWidget(tester);
        });

    testWidgets('falls back to "?" avatar initial when username is blank',
            (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: VideoCallScreen(
                username: '   ',
                isVideoEnabled: false,
                agoraService: fakeAgora,
              ),
            ),
          );
          await pumpStartAgora(tester);

          expect(find.text('?'), findsOneWidget);

          await disposeWidget(tester);
        });

    testWidgets('shows the permission banner when permission is denied',
            (tester) async {
          fakeAgora.grantPermissions = false;
          fakeAgora.permissionsPermanentlyDenied = false;

          await tester.pumpWidget(
            MaterialApp(
              home: VideoCallScreen(
                username: 'frank',
                isVideoEnabled: true,
                agoraService: fakeAgora,
              ),
            ),
          );
          await pumpStartAgora(tester);

          expect(
            find.text('Camera & microphone access is required for calls.'),
            findsOneWidget,
          );
          expect(find.text('Retry'), findsWidgets);
          expect(fakeAgora.joinChannelCallCount, 0);

          await disposeWidget(tester);
        });

    testWidgets('shows "Open Settings" when permission is permanently denied',
            (tester) async {
          fakeAgora.grantPermissions = false;
          fakeAgora.permissionsPermanentlyDenied = true;

          await tester.pumpWidget(
            MaterialApp(
              home: VideoCallScreen(
                username: 'grace',
                isVideoEnabled: true,
                agoraService: fakeAgora,
              ),
            ),
          );
          await pumpStartAgora(tester);

          expect(
            find.text(
                'Camera & microphone access was denied. Enable it in Settings to continue.'),
            findsOneWidget,
          );
          expect(find.text('Open Settings'), findsOneWidget);

          await disposeWidget(tester);
        });

    testWidgets(
        'shows the retrying banner then the terminal error banner when '
            'joinChannel keeps failing', (tester) async {
      fakeAgora.throwOnJoinChannel = true;

      await tester.pumpWidget(
        MaterialApp(
          home: VideoCallScreen(
            username: 'hank',
            isVideoEnabled: true,
            agoraService: fakeAgora,
          ),
        ),
      );
      await pumpStartAgora(tester);

      expect(find.textContaining('Connection issue'), findsOneWidget);

      // Let all 3 auto-retries (2s, 4s, 6s backoff) run to exhaustion so
      // no Timer is left pending when the test tears down.
      await tester.pump(const Duration(seconds: 3));
      await pumpStartAgora(tester);
      await tester.pump(const Duration(seconds: 5));
      await pumpStartAgora(tester);
      await tester.pump(const Duration(seconds: 7));
      await pumpStartAgora(tester);

      expect(
        find.text("Couldn't connect to the call. Please try again."),
        findsOneWidget,
      );

      await disposeWidget(tester);
    });

    testWidgets('tapping the back button ends the call and pops the route',
            (tester) async {
          await tester.pumpWidget(MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => VideoCallScreen(
                          username: 'ivan',
                          isVideoEnabled: false,
                          agoraService: fakeAgora,
                        ),
                      ));
                    },
                    child: const Text('Start Call'),
                  ),
                ),
              ),
            ),
          ));

          await tester.tap(find.text('Start Call'));
          await tester.pumpAndSettle();
          expect(find.byType(VideoCallScreen), findsOneWidget);

          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();

          expect(find.byType(VideoCallScreen), findsNothing);
          expect(find.text('Start Call'), findsOneWidget);
        });

    testWidgets('call duration timer increments the displayed time',
            (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: VideoCallScreen(
                username: 'jill',
                isVideoEnabled: false,
                agoraService: fakeAgora,
              ),
            ),
          );
          await pumpStartAgora(tester);

          expect(find.text('00:00'), findsOneWidget);

          await tester.pump(const Duration(seconds: 3));

          expect(find.text('00:03'), findsOneWidget);

          await disposeWidget(tester);
        });
  });
}
