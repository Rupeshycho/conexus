import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:conexus/view/message_individual_frame.dart';
import 'package:conexus/view/group_chat_screen.dart';
import 'package:conexus/view/incoming_call_dialog.dart';
import 'package:conexus/view/video_call_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final AudioPlayer _messagePlayer = AudioPlayer();

  StreamSubscription? _authSubscription;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _callSubscription;

  final Map<String, Timestamp> _lastMessageNotifiedTimes = {};
  final Set<String> _processedCallIds = {};

  Future<void> init() async {
    try {
      // 1. Request essential permissions
      await [
        Permission.notification,
        Permission.microphone,
        Permission.camera,
      ].request();

      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // 2. Setup Android Notification Channels
        final androidImplementation = _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
            
        await androidImplementation?.createNotificationChannel(const AndroidNotificationChannel(
          'conexus_channel_id',
          'Conexus Messages',
          description: 'Notifications for new messages',
          importance: Importance.max,
          playSound: true,
        ));

        await androidImplementation?.createNotificationChannel(const AndroidNotificationChannel(
          'conexus_call_channel_id',
          'Conexus Calls',
          description: 'Notifications for incoming calls',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ));

        // 3. Initialize Local Notifications
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const iosSettings = DarwinInitializationSettings();
        
        await _localNotificationsPlugin.initialize(
          const InitializationSettings(android: androidSettings, iOS: iosSettings),
          onDidReceiveNotificationResponse: _handleNotificationResponse,
        );

        // 4. Token Management
        String? token = await _fcm.getToken();
        if (token != null) _saveTokenToFirestore(token);
        _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

        // 5. Foreground Messaging Listener
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (message.notification != null) {
            _playMessageSound();
            _showLocalNotification(
              message.notification!.title ?? 'New Message',
              message.notification!.body ?? '',
              data: message.data,
            );
          }
        });
      }

      // 6. Immediate Auth Check
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _startListeningToFirestore(currentUser.uid);
        saveToken();
      }

      // 7. Sync with Auth State changes
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
    debugPrint("NotificationService: Monitoring Firestore for $currentUserId");
    _stopListeningToFirestore();

    // MESSAGE MONITOR
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

        if (lastMsgSenderId == currentUserId || lastMsg.isEmpty) continue;

        if (ChatScreen.activeChatUserId == lastMsgSenderId || GroupChatScreen.activeChatRoomId == roomId) {
          _lastMessageNotifiedTimes[roomId] = msgTime;
          continue;
        }

        final lastNotifiedTime = _lastMessageNotifiedTimes[roomId];
        if (lastNotifiedTime == null || msgTime.compareTo(lastNotifiedTime) > 0) {
          _lastMessageNotifiedTimes[roomId] = msgTime;
          final isGroup = data['isGroup'] == true;
          final names = Map<String, dynamic>.from(data['names'] ?? {});
          final title = isGroup 
              ? (data['groupName'] ?? 'Group Message') 
              : (names[lastMsgSenderId] ?? 'New Message');

          _playMessageSound();
          _showLocalNotification(
            title.toString(),
            isGroup ? "${names[lastMsgSenderId] ?? 'User'}: $lastMsg" : lastMsg,
            data: {'chatId': roomId, 'senderId': lastMsgSenderId, 'isGroup': isGroup},
          );
        }
      }
    });

    // CALL MONITOR
    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: currentUserId)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final callId = doc.id;
        final status = data['status'] as String? ?? 'dialing';
        final callerId = data['callerId'] as String? ?? '';
        final timestamp = data['timestamp'] as Timestamp?;

        if (callerId == currentUserId) continue;
        if (timestamp != null && DateTime.now().difference(timestamp.toDate()).abs().inMinutes > 5) continue;

        if (status == 'dialing') {
          if (!_processedCallIds.contains(callId)) {
            _processedCallIds.add(callId);
            _handleIncomingCall(callId, data);
          }
        } else {
          _stopRingtone();
          _localNotificationsPlugin.cancel(callId.hashCode);
        }
      }
    });
  }

  void _handleIncomingCall(String callId, Map<String, dynamic> data) {
    final String callerId = data['callerId']?.toString() ?? '';
    final String callerName = data['callerName']?.toString() ?? 'User';
    final String callerImage = data['callerImage']?.toString() ?? '';
    final bool isVideo = data['isVideo'] == true;

    _startRingtone();
    _showCallNotification(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerImage: callerImage,
      isVideo: isVideo,
    );

    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => IncomingCallDialog(
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          callerImage: callerImage,
          isVideo: isVideo,
        ),
      ).then((_) => _stopRingtone());
    }
  }

  void _startRingtone() async {
    try {
      _ringtonePlayer.audioCache.prefix = ''; 
      await _ringtonePlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.notificationRingtone,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
      ));
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.play(AssetSource('Assets/Sounds/ringtone.mp3'));
    } catch (e) {
      debugPrint("Error playing ringtone: $e");
    }
  }

  void _stopRingtone() async {
    try {
      await _ringtonePlayer.stop();
    } catch (e) {
      debugPrint("Error stopping ringtone: $e");
    }
  }

  void _playMessageSound() async {
    try {
      _messagePlayer.audioCache.prefix = '';
      await _messagePlayer.play(AssetSource('Assets/Sounds/ringtone.mp3'));
      Future.delayed(const Duration(seconds: 1), () => _messagePlayer.stop());
    } catch (e) {
      debugPrint("Error playing message sound: $e");
    }
  }

  void _stopListeningToFirestore() {
    _messageSubscription?.cancel();
    _callSubscription?.cancel();
    _messageSubscription = null;
    _callSubscription = null;
    _lastMessageNotifiedTimes.clear();
    _processedCallIds.clear();
    _stopRingtone();
  }

  Future<void> saveToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) _saveTokenToFirestore(token);
    } catch (e) {
      debugPrint("FCM Token save failed: $e");
    }
  }

  void _handleNotificationResponse(NotificationResponse response) async {
    _stopRingtone();
    final payload = response.payload;
    if (payload == null) return;
    final Map<String, dynamic> data = jsonDecode(payload);

    if (response.actionId == 'accept_call_action') {
      final String? callId = data['callId']?.toString();
      final String? callerId = data['callerId']?.toString();
      final String? callerName = data['callerName']?.toString();
      final bool isVideo = data['isVideo'] == true || data['isVideo'] == 'true';
      
      if (callId != null && callerName != null) {
        try {
          await FirebaseFirestore.instance.collection('calls').doc(callId).update({'status': 'connected'});
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => VideoCallScreen(
              username: callerName, 
              isVideoEnabled: isVideo, 
              callId: callId, 
              isIncoming: true, 
              receiverId: callerId
            )));
          }
        } catch (e) {
          debugPrint("Error accepting call: $e");
        }
      }
    } else if (response.actionId == 'decline_call_action') {
      final String? callId = data['callId']?.toString();
      if (callId != null) {
        FirebaseFirestore.instance.collection('calls').doc(callId).update({'status': 'declined'});
      }
    } else if (response.actionId == 'reply_action' && response.input != null) {
      if (data['chatId'] != null && data['senderId'] != null) {
        await _sendReplyFromNotification(data['chatId'].toString(), data['senderId'].toString(), response.input!);
      }
    } else {
      _navigateToTarget(data);
    }
  }

  void _navigateToTarget(Map<String, dynamic> data) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (data['type'] == 'call') {
      final String callId = data['callId']?.toString() ?? '';
      if (callId.isEmpty) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => IncomingCallDialog(
          callId: callId, 
          callerId: data['callerId']?.toString() ?? '', 
          callerName: data['callerName']?.toString() ?? 'User', 
          callerImage: data['callerImage']?.toString() ?? '',
          isVideo: data['isVideo'] == true || data['isVideo'] == 'true'
        ),
      ).then((_) => _stopRingtone());
    } else if (data['senderId'] != null) {
      final userSnap = await FirebaseFirestore.instance.collection('users').doc(data['senderId'].toString()).get();
      if (userSnap.exists && context.mounted) {
        final userData = userSnap.data();
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
          receiverId: data['senderId'].toString(), 
          username: userData?['name']?.toString() ?? 'User', 
          profileImage: userData?['profileImage']?.toString() ?? ''
        )));
      }
    }
  }

  Future<void> _sendReplyFromNotification(String chatId, String receiverId, String text) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    final now = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance.collection('chat_rooms').doc(chatId).collection('messages').add({
      'text': text, 'imageUrl': '', 'type': 'text', 'status': 'sent', 'isEdited': false, 
      'senderId': currentUserId, 'receiverId': receiverId, 'time': now, 'reactions': {}
    });
    await FirebaseFirestore.instance.collection('chat_rooms').doc(chatId).update({
      'lastMessage': text, 'lastMessageSenderId': currentUserId, 'lastMessageTime': now, 
      'unreadCount.$receiverId': FieldValue.increment(1)
    });
  }

  void _saveTokenToFirestore(String token) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUserId).set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  void _showLocalNotification(String title, String body, {Map<String, dynamic>? data}) async {
    const androidDetails = AndroidNotificationDetails(
      'conexus_channel_id', 'Conexus Messages', 
      importance: Importance.max, priority: Priority.high, 
      actions: [AndroidNotificationAction('reply_action', 'Reply', inputs: [AndroidNotificationActionInput(label: 'Type your message...')])]
    );
    await _localNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, 
      const NotificationDetails(android: androidDetails), 
      payload: data != null ? jsonEncode(data) : null
    );
  }

  void _showCallNotification({
    required String callId, 
    required String callerId, 
    required String callerName, 
    required String callerImage, 
    required bool isVideo
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'conexus_call_channel_id', 'Conexus Calls', 
      importance: Importance.max, priority: Priority.high, 
      fullScreenIntent: true, category: AndroidNotificationCategory.call, 
      actions: [
        const AndroidNotificationAction('accept_call_action', 'Accept', showsUserInterface: true), 
        const AndroidNotificationAction('decline_call_action', 'Decline')
      ]
    );
    await _localNotificationsPlugin.show(
      callId.hashCode, isVideo ? "Incoming Video Call" : "Incoming Voice Call", 
      "$callerName is calling...", 
      NotificationDetails(android: androidDetails), 
      payload: jsonEncode({
        'callId': callId, 'callerId': callerId, 'callerName': callerName, 
        'callerImage': callerImage, 'isVideo': isVideo, 'type': 'call'
      })
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("NotificationService: Handling background message: ${message.messageId}");
}
