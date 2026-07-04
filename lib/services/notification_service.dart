import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:conexus/view/message_individual_frame.dart';
import 'package:conexus/view/group_chat_screen.dart';
import 'package:conexus/view/incoming_call_dialog.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  StreamSubscription? _authSubscription;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _callSubscription;

  final Map<String, Timestamp> _lastMessageNotifiedTimes = {};
  final Set<String> _processedCallIds = {};

  Future<void> init() async {
    try {
      // Request permissions for iOS/Android 13+
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Initialize local notifications
        const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
        
        const InitializationSettings initSettings = InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        );

        await _localNotificationsPlugin.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            _handleNotificationResponse(response);
          },
        );

        // Get FCM token
        String? token = await _fcm.getToken();
        if (token != null) {
          _saveTokenToFirestore(token);
        }

        // Listen for token refreshes
        _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

        // Listen for foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (message.notification != null) {
            _showLocalNotification(
              message.notification!.title ?? 'New Message',
              message.notification!.body ?? '',
              data: message.data,
            );
          }
        });
      }

      // Track auth state changes to start/stop listening to Firestore updates
      _authSubscription?.cancel();
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          _startListeningToFirestore(user.uid);
          saveToken();
        } else {
          _stopListeningToFirestore();
        }
      });
    } catch (e) {
      debugPrint("NotificationService init failed: $e");
    }
  }

  void _startListeningToFirestore(String currentUserId) {
    _stopListeningToFirestore();

    // 1. Listen for new messages across all chat rooms where the user is a participant
    _messageSubscription = FirebaseFirestore.instance
        .collection('chat_rooms')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final roomId = doc.id;
        final lastMsg = data['lastMessage'] as String? ?? '';
        final lastMsgSenderId = data['lastMessageSenderId'] as String? ?? '';
        final msgTime = (data['lastMessageTime'] as Timestamp?) ?? Timestamp.now();

        if (lastMsgSenderId == currentUserId || lastMsg.isEmpty) {
          continue;
        }

        // If the user is currently looking at this individual chat or group room, do not send a notification
        if (ChatScreen.activeChatUserId == lastMsgSenderId || GroupChatScreen.activeChatRoomId == roomId) {
          _lastMessageNotifiedTimes[roomId] = msgTime;
          continue;
        }

        final lastNotifiedTime = _lastMessageNotifiedTimes[roomId];
        if (lastNotifiedTime == null) {
          // Initialize timestamp to prevent old notifications from triggering on app startup
          _lastMessageNotifiedTimes[roomId] = msgTime;
        } else if (msgTime.compareTo(lastNotifiedTime) > 0) {
          // New message received! Update time and show notification
          _lastMessageNotifiedTimes[roomId] = msgTime;

          final isGroup = data['isGroup'] == true;
          final names = Map<String, dynamic>.from(data['names'] ?? {});
          final displayTitle = isGroup
              ? (data['groupName']?.toString() ?? 'Group Message')
              : (names[lastMsgSenderId]?.toString() ?? 'New Message');

          final bodyText = isGroup
              ? "${names[lastMsgSenderId] ?? 'User'}: $lastMsg"
              : lastMsg;

          _showLocalNotification(
            displayTitle,
            bodyText,
            data: {
              'chatId': roomId,
              'senderId': lastMsgSenderId,
              'isGroup': isGroup,
            },
          );
        }
      }
    });

    // 2. Listen for incoming calls where status is 'dialing' and current user is receiver
    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'dialing')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final callId = doc.id;
        final callerId = data['callerId'] as String? ?? '';
        final callerName = data['callerName'] as String? ?? 'User';
        final callerImage = data['callerImage'] as String? ?? '';
        final isVideo = data['isVideo'] as bool? ?? false;
        final timestamp = data['timestamp'] as Timestamp?;

        if (callerId == currentUserId) continue;

        // Skip if call document is older than 1 minute to prevent stale alerts
        if (timestamp != null) {
          final age = DateTime.now().difference(timestamp.toDate());
          if (age.inMinutes > 1) {
            continue;
          }
        }

        if (!_processedCallIds.contains(callId)) {
          _processedCallIds.add(callId);

          // Show local call notification
          _showLocalNotification(
            isVideo ? "Incoming Video Call" : "Incoming Voice Call",
            "$callerName is calling you...",
            data: {
              'callId': callId,
              'callerName': callerName,
              'callerImage': callerImage,
              'isVideo': isVideo,
              'type': 'call',
            },
          );

          // Show the fullscreen incoming call dialog
          final context = navigatorKey.currentContext;
          if (context != null) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => IncomingCallDialog(
                callId: callId,
                callerName: callerName,
                callerImage: callerImage,
                isVideo: isVideo,
              ),
            );
          }
        }
      }
    });
  }

  void _stopListeningToFirestore() {
    _messageSubscription?.cancel();
    _callSubscription?.cancel();
    _messageSubscription = null;
    _callSubscription = null;
    _lastMessageNotifiedTimes.clear();
    _processedCallIds.clear();
  }

  Future<void> saveToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint("Error saving token: $e");
    }
  }

  // Handle actions like 'Reply' from the notification tray
  void _handleNotificationResponse(NotificationResponse response) async {
    final String? payload = response.payload;
    if (payload != null) {
      final Map<String, dynamic> data = jsonDecode(payload);
      final String? chatId = data['chatId'];
      final String? senderId = data['senderId']; // The person who sent the original message

      // Handle Direct Reply action
      if (response.actionId == 'reply_action' && response.input != null) {
        String replyText = response.input!;
        if (chatId != null && senderId != null && replyText.isNotEmpty) {
          await _sendReplyFromNotification(chatId, senderId, replyText);
        }
      } else {
        // Handle normal notification tap
        if (data['type'] == 'call') {
          final String? callId = data['callId'];
          final String? callerName = data['callerName'];
          final String? callerImage = data['callerImage'];
          final bool isVideo = data['isVideo'] == true || data['isVideo'] == 'true';

          final context = navigatorKey.currentContext;
          if (context != null && callId != null && callerName != null) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => IncomingCallDialog(
                callId: callId,
                callerName: callerName,
                callerImage: callerImage ?? '',
                isVideo: isVideo,
              ),
            );
          }
        } else {
          // Handle message notification tap (navigate to the chat screen)
          final targetSenderId = senderId ?? data['senderId'];
          if (targetSenderId != null) {
            final context = navigatorKey.currentContext;
            if (context != null) {
              try {
                final userSnap = await FirebaseFirestore.instance.collection('users').doc(targetSenderId).get();
                if (userSnap.exists && context.mounted) {
                  final userData = userSnap.data();
                  final userName = userData?['name'] as String? ?? 'User';
                  final userImage = userData?['profileImage'] as String? ?? '';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        receiverId: targetSenderId,
                        username: userName,
                        profileImage: userImage,
                      ),
                    ),
                  );
                }
              } catch (e) {
                debugPrint("Error navigating to chat: $e");
              }
            }
          }
        }
      }
    }
  }

  Future<void> _sendReplyFromNotification(String chatId, String receiverId, String text) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final now = FieldValue.serverTimestamp();
    
    // 1. Add reply message to the subcollection
    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatId)
        .collection('messages')
        .add({
      'text': text,
      'imageUrl': '',
      'type': 'text',
      'status': 'sent',
      'isEdited': false,
      'senderId': currentUserId,
      'receiverId': receiverId,
      'time': now,
      'reactions': {},
    });

    // 2. Update the parent chat room info
    await FirebaseFirestore.instance.collection('chat_rooms').doc(chatId).update({
      'lastMessage': text,
      'lastMessageSenderId': currentUserId,
      'lastMessageTime': now,
      'unreadCount.$receiverId': FieldValue.increment(1),
    });
  }

  void _saveTokenToFirestore(String token) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUserId).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    }
  }

  void _showLocalNotification(String title, String body, {Map<String, dynamic>? data}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'conexus_channel_id',
      'Conexus Messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      // Adding the 'Reply' action that appears on long-press or expansion
      actions: [
        AndroidNotificationAction(
          'reply_action',
          'Reply',
          inputs: [
            AndroidNotificationActionInput(label: 'Type your message...'),
          ],
        ),
      ],
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
      payload: data != null ? jsonEncode(data) : null,
    );
  }
}

// Background handler (Must be a top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}
