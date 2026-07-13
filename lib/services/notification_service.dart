import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../model/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  late final AudioPlayer _messagePlayer;

  StreamSubscription? _authSubscription;
  StreamSubscription? _notificationSubscription;

  // Used to tell "new since I started listening" apart from the existing
  // backlog, so re-attaching the listener (e.g. on token refresh) doesn't
  // re-fire a local notification for every historical unread doc.
  DateTime? _listenerStartedAt;

  // Monotonically increasing so two notifications shown in the same second
  // don't collide and overwrite each other on Android.
  int _localNotificationCounter = 0;

  // ─── INIT ──────────────────────────────────────────────

  Future<void> init() async {
    _messagePlayer = AudioPlayer();
    try {
      // Only notification permission belongs here — camera/microphone are
      // unrelated to notifications and shouldn't be requested from this
      // service; request them where they're actually used.
      await Permission.notification.request();

      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final androidImplementation =
            _localNotificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        await androidImplementation?.createNotificationChannel(
          const AndroidNotificationChannel(
            'conexus_channel_id',
            'Conexus Notifications',
            description: 'Notifications for likes, comments, shares, etc.',
            importance: Importance.max,
            playSound: true,
          ),
        );

        await _localNotificationsPlugin.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
          onDidReceiveNotificationResponse: _handleNotificationResponse,
          onDidReceiveBackgroundNotificationResponse:
              _handleBackgroundNotificationResponse,
        );

        // Let FCM show its own banner while the app is foregrounded on iOS,
        // instead of relying solely on the local-notifications plugin.
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        String? token = await _fcm.getToken();
        if (token != null) await _saveTokenToFirestore(token);
        _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (message.notification != null) {
            // _playMessageSound();  // Commented out – no asset needed
            _showLocalNotification(
              message.notification!.title ?? 'Conexus',
              message.notification!.body ?? '',
              data: message.data,
            );
          }
        });
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _startListeningToFirestore(currentUser.uid);
        await saveToken();
      }

      _authSubscription?.cancel();
      _authSubscription =
          FirebaseAuth.instance.authStateChanges().listen((user) {
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

  // ─── SOUND (disabled) ──────────────────────────────────

  void _playMessageSound() {
    // Sound disabled – add asset and uncomment to enable
    // try {
    //   await _messagePlayer.play(AssetSource('sounds/message.mp3'));
    //   Future.delayed(const Duration(seconds: 1), () {
    //     _messagePlayer.stop();
    //   });
    // } catch (e) {
    //   debugPrint("Error playing message sound: $e");
    // }
  }

  // ─── FIRESTORE LISTENER ─────────────────────────────────

  void _startListeningToFirestore(String currentUserId) {
    _stopListeningToFirestore();
    _listenerStartedAt = DateTime.now();

    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('toUserId', isEqualTo: currentUserId)
        .snapshots()
        .listen((snapshot) {
      // Only react to docs that were newly ADDED to the result set, not the
      // full backlog Firestore hands back on the very first snapshot. This
      // is what stops every historical unread notification from firing a
      // banner the moment the listener (re)attaches.
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;

        final data = change.doc.data();
        if (data == null) continue;

        final isRead = data['isRead'] as bool? ?? false;
        if (isRead) continue;

        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final startedAt = _listenerStartedAt;
        if (createdAt != null &&
            startedAt != null &&
            createdAt.isBefore(startedAt)) {
          // Pre-existing notification from before this listener attached —
          // part of the backlog, not a new event. Skip it.
          continue;
        }

        // message is computed from type + fromUsername, not stored, so we
        // reuse the model's own getter instead of re-deriving it here.
        final notification = NotificationModel.fromFirestore(change.doc);
        _showLocalNotification(
          'Conexus',
          notification.message,
          data: {'notificationId': change.doc.id},
        );
      }
    });
  }

  void _stopListeningToFirestore() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _listenerStartedAt = null;
  }

  // ─── FCM TOKEN ──────────────────────────────────────────

  Future<void> saveToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) await _saveTokenToFirestore(token);
    } catch (e) {
      debugPrint("FCM Token save failed: $e");
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  // ─── LOCAL NOTIFICATIONS ───────────────────────────────

  Future<void> _showLocalNotification(
    String title,
    String body, {
    Map<String, dynamic>? data,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'conexus_channel_id',
        'Conexus Notifications',
        importance: Importance.max,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      await _localNotificationsPlugin.show(
        _nextLocalNotificationId(),
        title,
        body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: data != null ? jsonEncode(data) : null,
      );
    } catch (e) {
      debugPrint("Error showing local notification: $e");
    }
  }

  int _nextLocalNotificationId() {
    // Wrap well within the 32-bit range the plugin expects.
    _localNotificationCounter = (_localNotificationCounter + 1) % 100000;
    return _localNotificationCounter;
  }

  // ─── NOTIFICATION RESPONSE HANDLERS ────────────────────

  void _handleNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;
    try {
      final Map<String, dynamic> data = jsonDecode(payload);
      if (data['notificationId'] != null) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(data['notificationId'])
            .update({'isRead': true});
      }
    } catch (e) {
      debugPrint("Error handling notification response: $e");
    }
  }

  static void _handleBackgroundNotificationResponse(
      NotificationResponse response) {
    debugPrint("Background notification tapped: ${response.payload}");
  }

  // ─── STATIC API METHODS ──────────────────────────────────

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static void showSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  static Future<void> createNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUsername,
    String fromUserPhotoUrl = '',
    required NotificationType type,
    String postId = '',
  }) async {
    // Prevent self‑notification
    if (toUserId == fromUserId) return;
    final notification = NotificationModel(
      notificationId: '',
      type: type,
      postId: postId,
      fromUserId: fromUserId,
      fromUsername: fromUsername,
      fromUserPhotoUrl: fromUserPhotoUrl,
      toUserId: toUserId,
      isRead: false,
      createdAt: DateTime.now(),
    );
    await _firestore.collection('notifications').add(notification.toMap());
  }

  static Stream<List<NotificationModel>> getNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList(),
        );
  }

  static Future<void> markRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  static Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  // ─── DISPOSE ────────────────────────────────────────────

  void dispose() {
    _authSubscription?.cancel();
    _notificationSubscription?.cancel();
    _messagePlayer.dispose();
  }
}

// ─── BACKGROUND MESSAGE HANDLER ──────────────────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling background message: ${message.messageId}");
}
