
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:conexus/repo/user_repo.dart'; // TODO: fix this path
import 'package:conexus/view/message_individual_frame.dart' show ChatScreen;

class _MockUserRepo extends Mock implements UserRepo {}

void main() {
  // ---------------------------------------------------------------------
  // Pure logic: room-id derivation.
  // Mirrors _ChatScreenState.getChatRoomId — two participants should
  // always land on the same room id regardless of call order, since the
  // real implementation sorts the pair before joining them.
  // ---------------------------------------------------------------------
  group('chat room id derivation', () {
    String getChatRoomId(String uid1, String uid2) {
      final list = [uid1, uid2]..sort();
      return '${list[0]}_${list[1]}';
    }
    test('is symmetric regardless of argument order', () {
      expect(getChatRoomId('userA', 'userB'), getChatRoomId('userB', 'userA'));
    });

    test('joins the sorted ids with an underscore', () {
      expect(getChatRoomId('zzz', 'aaa'), 'aaa_zzz');
    });

    test('is deterministic across repeated calls', () {
      expect(getChatRoomId('u1', 'u2'), getChatRoomId('u1', 'u2'));
    });

    test('handles identical ids without throwing', () {
      expect(getChatRoomId('u1', 'u1'), 'u1_u1');
    });
  });

  // ---------------------------------------------------------------------
  // Static state: ChatScreen.activeChatUserId.
  // ---------------------------------------------------------------------
  group('ChatScreen.activeChatUserId', () {
    setUp(() => ChatScreen.activeChatUserId = null);
    tearDown(() => ChatScreen.activeChatUserId = null);

    test('is null until a chat screen sets it', () {
      expect(ChatScreen.activeChatUserId, isNull);
    });

    test('can be assigned and cleared like the widget does on init/dispose', () {
      ChatScreen.activeChatUserId = 'receiver-123';
      expect(ChatScreen.activeChatUserId, 'receiver-123');
      ChatScreen.activeChatUserId = null;
      expect(ChatScreen.activeChatUserId, isNull);
    });
  });

  // ---------------------------------------------------------------------
  // Widget tests — require the constructor seam described above.
  // ---------------------------------------------------------------------
  group('ChatScreen widget', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    const currentUid = 'me-uid';
    const receiverUid = 'receiver-uid';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(
        mockUser: MockUser(uid: currentUid, email: 'me@example.com'),
        signedIn: true,
      );
      ChatScreen.activeChatUserId = null;
    });

    Widget buildTestable() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<UserViewModel>(
            create: (_) => UserViewModel(userRepo: _MockUserRepo()),
          ),
        ],
        child: MaterialApp(
          home: ChatScreen(
            receiverId: receiverUid,
            username: 'Jane Doe',
            profileImage: '',
            firestore: firestore,
            auth: auth,
          ),
        ),
      );
    }

    testWidgets('renders the receiver name and an empty conversation without crashing',
            (tester) async {
          await tester.pumpWidget(buildTestable());
          await tester.pumpAndSettle();

          expect(find.text('Jane Doe'), findsOneWidget);
          expect(find.text('Type message...'), findsOneWidget);
        });

    testWidgets('sets activeChatUserId to the receiver on init and clears it on dispose',
            (tester) async {
          await tester.pumpWidget(buildTestable());
          await tester.pump();
          expect(ChatScreen.activeChatUserId, receiverUid);

          // Replace with an empty widget to trigger dispose.
          await tester.pumpWidget(const MaterialApp(home: SizedBox()));
          await tester.pump();
          expect(ChatScreen.activeChatUserId, isNull);
        });

    testWidgets('sending a text message writes it to Firestore and clears the input',
            (tester) async {
          await tester.pumpWidget(buildTestable());
          await tester.pumpAndSettle();

          await tester.enterText(find.byType(TextField), 'hello there');
          await tester.tap(find.byIcon(Icons.send));
          await tester.pumpAndSettle();

          final list = [currentUid, receiverUid]..sort();
          final chatRoomId = '${list[0]}_${list[1]}';

          final messages = await firestore
              .collection('chat_rooms')
              .doc(chatRoomId)
              .collection('messages')
              .get();

          expect(messages.docs, hasLength(1));
          expect(messages.docs.first.data()['text'], 'hello there');
          expect(messages.docs.first.data()['senderId'], currentUid);

          // Input should be cleared after a text send.
          final textField = tester.widget<TextField>(find.byType(TextField));
          expect(textField.controller?.text, isEmpty);
        });

    testWidgets('sending updates the parent chat_room doc with lastMessage and unread count',
            (tester) async {
          await tester.pumpWidget(buildTestable());
          await tester.pumpAndSettle();

          await tester.enterText(find.byType(TextField), 'ping');
          await tester.tap(find.byIcon(Icons.send));
          await tester.pumpAndSettle();

          final list = [currentUid, receiverUid]..sort();
          final chatRoomId = '${list[0]}_${list[1]}';

          final roomDoc = await firestore.collection('chat_rooms').doc(chatRoomId).get();
          expect(roomDoc.data()?['lastMessage'], 'ping');
          expect(roomDoc.data()?['lastMessageSenderId'], currentUid);
          expect(roomDoc.data()?['unreadCount']?[receiverUid], 1);
        });

    testWidgets('does not send an empty message', (tester) async {
      await tester.pumpWidget(buildTestable());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      final list = [currentUid, receiverUid]..sort();
      final chatRoomId = '${list[0]}_${list[1]}';
      final messages = await firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .get();

      expect(messages.docs, isEmpty);
    });

    testWidgets('tapping the attachment icon shows camera/gallery/video/file options',
            (tester) async {
          await tester.pumpWidget(buildTestable());
          await tester.pumpAndSettle();

          await tester.tap(find.byIcon(Icons.add));
          await tester.pumpAndSettle();

          expect(find.text('Camera'), findsOneWidget);
          expect(find.text('Gallery (Photo)'), findsOneWidget);
          expect(find.text('Video'), findsOneWidget);
          expect(find.text('Document / File'), findsOneWidget);
        });

    testWidgets('long-pressing my own text message shows edit and delete options',
            (tester) async {
          final list = [currentUid, receiverUid]..sort();
          final chatRoomId = '${list[0]}_${list[1]}';

          await firestore
              .collection('chat_rooms')
              .doc(chatRoomId)
              .collection('messages')
              .add({
            'text': 'my message',
            'imageUrl': '',
            'type': 'text',
            'status': 'sent',
            'isEdited': false,
            'isForwarded': false,
            'senderId': currentUid,
            'receiverId': receiverUid,
            'time': Timestamp.now(),
            'reactions': {},
            'replyTo': null,
          });

          await tester.pumpWidget(buildTestable());
          await tester.pumpAndSettle();

          await tester.longPress(find.text('my message'));
          await tester.pumpAndSettle();

          expect(find.text('Edit Message'), findsOneWidget);
          expect(find.text('Delete Message'), findsOneWidget);
          expect(find.text('Reply'), findsOneWidget);
        });

    testWidgets('long-pressing the other person message hides edit, keeps reply',
            (tester) async {
          final list = [currentUid, receiverUid]..sort();
          final chatRoomId = '${list[0]}_${list[1]}';

          await firestore
              .collection('chat_rooms')
              .doc(chatRoomId)
              .collection('messages')
              .add({
            'text': 'their message',
            'imageUrl': '',
            'type': 'text',
            'status': 'sent',
            'isEdited': false,
            'isForwarded': false,
            'senderId': receiverUid,
            'receiverId': currentUid,
            'time': Timestamp.now(),
            'reactions': {},
            'replyTo': null,
          });

          await tester.pumpWidget(buildTestable());
          await tester.pumpAndSettle();

          await tester.longPress(find.text('their message'));
          await tester.pumpAndSettle();

          expect(find.text('Edit Message'), findsNothing);
          expect(find.text('Delete Message'), findsNothing);
          expect(find.text('Reply'), findsOneWidget);
        });

    testWidgets('choosing Reply shows the reply preview bar, and the close button clears it',
            (tester) async {
          final list = [currentUid, receiverUid]..sort();
          final chatRoomId = '${list[0]}_${list[1]}';

          await firestore
              .collection('chat_rooms')
              .doc(chatRoomId)
              .collection('messages')
              .add({
            'text': 'quote me',
            'imageUrl': '',
            'type': 'text',
            'status': 'sent',
            'isEdited': false,
            'isForwarded': false,
            'senderId': receiverUid,
            'receiverId': currentUid,
            'time': Timestamp.now(),
            'reactions': {},
            'replyTo': null,
          });

          await tester.pumpWidget(buildTestable());
          await tester.pumpAndSettle();

          await tester.longPress(find.text('quote me'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Reply'));
          await tester.pumpAndSettle();

          expect(find.textContaining('Replying to'), findsOneWidget);

          await tester.tap(find.byIcon(Icons.close));
          await tester.pumpAndSettle();

          expect(find.textContaining('Replying to'), findsNothing);
        });

    testWidgets('confirming delete removes the message from Firestore', (tester) async {
      final list = [currentUid, receiverUid]..sort();
      final chatRoomId = '${list[0]}_${list[1]}';

      final ref = await firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'text': 'delete me',
        'imageUrl': '',
        'type': 'text',
        'status': 'sent',
        'isEdited': false,
        'isForwarded': false,
        'senderId': currentUid,
        'receiverId': receiverUid,
        'time': Timestamp.now(),
        'reactions': {},
        'replyTo': null,
      });

      await tester.pumpWidget(buildTestable());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('delete me'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      final snapshot = await ref.get();
      expect(snapshot.exists, isFalse);
    });

    testWidgets('editing a message updates its text and marks it edited', (tester) async {
      final list = [currentUid, receiverUid]..sort();
      final chatRoomId = '${list[0]}_${list[1]}';

      final ref = await firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'text': 'original text',
        'imageUrl': '',
        'type': 'text',
        'status': 'sent',
        'isEdited': false,
        'isForwarded': false,
        'senderId': currentUid,
        'receiverId': receiverUid,
        'time': Timestamp.now(),
        'reactions': {},
        'replyTo': null,
      });

      await tester.pumpWidget(buildTestable());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('original text'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Message'));
      await tester.pumpAndSettle();

      final editField = find.widgetWithText(TextField, 'original text');
      await tester.enterText(editField, 'updated text');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final snapshot = await ref.get();
      expect(snapshot.data()?['text'], 'updated text');
      expect(snapshot.data()?['isEdited'], isTrue);
    });

    testWidgets('reacting to a message stores the emoji keyed by the current user',
            (tester) async {
          final list = [currentUid, receiverUid]..sort();
          final chatRoomId = '${list[0]}_${list[1]}';

          final ref = await firestore
              .collection('chat_rooms')
              .doc(chatRoomId)
              .collection('messages')
              .add({
            'text': 'react to this',
            'imageUrl': '',
            'type': 'text',
            'status': 'sent',
            'isEdited': false,
            'isForwarded': false,
            'senderId': receiverUid,
            'receiverId': currentUid,
            'time': Timestamp.now(),
            'reactions': {},
            'replyTo': null,
          });

          await tester.pumpWidget(buildTestable());
          await tester.pumpAndSettle();

          await tester.longPress(find.text('react to this'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('🔥'));
          await tester.pumpAndSettle();

          final snapshot = await ref.get();
          expect(snapshot.data()?['reactions']?[currentUid], '🔥');
        });
  });
}
