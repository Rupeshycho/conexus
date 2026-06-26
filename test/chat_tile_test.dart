import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conexus/view/chat_tile.dart';

void main() {
  testWidgets('ChatTile renders details correctly and responds to tap', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTile(
            username: 'John Doe',
            profileImage: 'https://i.pravatar.cc/150?u=johndoe',
            lastMessage: 'Hello there!',
            time: '10:30 AM',
            unreadCount: '3',
            isOnline: true,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    // Verify username renders
    expect(find.text('John Doe'), findsOneWidget);

    // Verify last message renders
    expect(find.text('Hello there!'), findsOneWidget);

    // Verify time renders
    expect(find.text('10:30 AM'), findsOneWidget);

    // Verify unread count renders
    expect(find.text('3'), findsOneWidget);

    // Verify online indicator container is present (isOnline: true)
    final onlineIndicatorFinder = find.byWidgetPredicate(
      (widget) => widget is Container && 
                  widget.decoration is BoxDecoration && 
                  (widget.decoration as BoxDecoration).color == Colors.green
    );
    expect(onlineIndicatorFinder, findsOneWidget);

    // Tap and check callback
    await tester.tap(find.text('John Doe'));
    expect(tapped, true);
  });
}
