import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conexus/view/video_call_screen.dart';

void main() {
  testWidgets('VideoCallScreen renders details and toggles state buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VideoCallScreen(
          username: 'Jane Smith',
          isVideoEnabled: true,
        ),
      ),
    );

    // Verify username renders
    expect(find.text('Jane Smith'), findsOneWidget);

    // Verify Title "Video Call" is shown when isVideoEnabled is true
    expect(find.text('Video Call'), findsOneWidget);
    expect(find.text('Video Calling...'), findsOneWidget);

    // Check default mic state icon (Icons.mic)
    expect(find.byIcon(Icons.mic), findsOneWidget);

    // Tap mic button (mute)
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();

    // Verify mic off icon is shown after toggle
    expect(find.byIcon(Icons.mic_off), findsOneWidget);

    // Toggle video camera off (Icons.videocam)
    expect(find.byIcon(Icons.videocam), findsOneWidget);
    await tester.tap(find.byIcon(Icons.videocam));
    await tester.pump();

    // Title should update to "Audio Call" and "Voice Calling..."
    expect(find.text('Audio Call'), findsOneWidget);
    expect(find.text('Voice Calling...'), findsOneWidget);
    expect(find.byIcon(Icons.videocam_off), findsOneWidget);

    // Toggle screen sharing (Icons.screen_share_rounded)
    expect(find.byIcon(Icons.screen_share_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.screen_share_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.stop_screen_share_rounded), findsOneWidget);
  });
}
