import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Matches main.dart, which initializes Firebase with
// `options: DefaultFirebaseOptions.currentPlatform`. Background isolates
// get no implicit config from the main isolate, so these entry points
// must pass the same options explicitly or init can silently resolve to
// the wrong (or no) project config.
import 'package:conexus/firebase_options.dart';
import 'package:conexus/view/group_chat_screen.dart';
import 'package:conexus/view/incoming_call_dialog.dart';
import 'package:conexus/view/message_individual_frame.dart';
import 'package:conexus/view/video_call_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// FIX (reply silently drops for push-originated notifications): the
/// Firestore-listener path always builds `chatId`/`senderId` explicitly,
/// but a raw FCM push (`FirebaseMessaging.onMessage`, or any backend
/// sending `notification` + `data`) may use different key names for the
/// same fields (e.g. `roomId`, `room_id`, `sender_id`, `from`). Previously
/// a mismatch here meant the reply/decline payload was missing the field
/// entirely and got silently dropped. This checks a list of common
/// variants in order and returns the first non-empty match, so the
/// client no longer depends on the backend using one exact spelling.
String? _firstNonEmpty(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value != null && value.toString().isNotEmpty) return value.toString();
  }
  return null;
}

const List<String> _chatIdKeys = ['chatId', 'roomId', 'room_id', 'chat_id'];
const List<String> _senderIdKeys = [
  'senderId',
  'sender_id',
  'senderID',
  'from',
  'fromUserId',
];

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final AudioPlayer _messagePlayer = AudioPlayer();

  StreamSubscription? _authSubscription;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _callSubscription;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;

  final Map<String, Timestamp> _lastMessageNotifiedTimes = {};
  final Set<String> _processedCallIds = {};

  bool _localNotificationsReady = false;

  static const String _iosMessageCategoryId = 'message_category';
  static const String _iosCallCategoryId = 'call_category';

  String? _activeRingingCallId;
  String? _activeCallDialogId;

  /// The uid currently being monitored, so a dropped listener can be
  /// restarted for the right user instead of silently going quiet.
  String? _currentListeningUid;

  /// Guards against a burst of listener errors triggering overlapping
  /// restart attempts for the message/call monitors.
  bool _isRestartingMessageListener = false;
  bool _isRestartingCallListener = false;

  /// Retries getting/saving the FCM token a few times on init failure —
  /// a transient network blip at app-launch shouldn't permanently mean
  /// this device never receives push notifications for incoming calls
  /// until the next app restart.
  int _fcmRetryCount = 0;
  static const int _maxFcmRetries = 3;
  Timer? _fcmRetryTimer;

  /// FIX (cold start / accept does nothing): a notification tap that
  /// LAUNCHES the app can be delivered to `_handleNotificationResponse`
  /// during `_localNotificationsPlugin.initialize()`, which runs inside
  /// `init()` — i.e. BEFORE `runApp()` has attached anything to
  /// `navigatorKey`. `navigatorKey.currentContext` is null at that
  /// moment, so navigation (e.g. pushing VideoCallScreen after accepting
  /// a call) previously just silently failed: the Firestore transaction
  /// still ran and marked the call 'connected', but nothing ever showed
  /// a screen for it. Any navigation attempted before the navigator
  /// exists is queued here and flushed by `flushPendingNavigation()`,
  /// which main.dart calls once the widget tree is actually up.
  VoidCallback? _pendingNavigation;

  void _tryNavigateOrQueue(VoidCallback navigate) {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      navigate();
    } else {
      debugPrint(
        "NotificationService: navigatorKey not attached yet, queuing navigation",
      );
      _pendingNavigation = navigate;
    }
  }

  /// Call once after the widget tree is up (see main.dart) to retry any
  /// navigation that arrived before `navigatorKey` had a context — e.g.
  /// the app was launched by tapping Accept on a call notification while
  /// killed.
  void flushPendingNavigation() {
    final nav = _pendingNavigation;
    if (nav == null) return;
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      _pendingNavigation = null;
      nav();
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => flushPendingNavigation(),
      );
    }
  }

  Future<void> init() async {
    try {
      await [Permission.notification].request();

      await _initLocalNotifications();

      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _setUpFcmToken();

        _onMessageSubscription?.cancel();
        _onMessageSubscription = FirebaseMessaging.onMessage.listen((
          RemoteMessage message,
        ) {
          if (message.notification != null) {
            unawaited(_playMessageSound());

            // FIX: normalize whatever key names the backend used into the
            // canonical 'chatId'/'senderId' the reply path expects, instead
            // of passing message.data straight through. See _firstNonEmpty
            // above for why this matters.
            final chatId = _firstNonEmpty(message.data, _chatIdKeys);
            final senderId = _firstNonEmpty(message.data, _senderIdKeys);
            final normalizedData = Map<String, dynamic>.from(message.data);
            if (chatId != null) normalizedData['chatId'] = chatId;
            if (senderId != null) normalizedData['senderId'] = senderId;

            if (chatId == null || senderId == null) {
              debugPrint(
                "NotificationService: push data missing chatId/senderId after normalization. "
                "Raw keys: ${message.data.keys.toList()} — reply for this notification will not work "
                "until the backend sends one of $_chatIdKeys / $_senderIdKeys.",
              );
            }

            _showLocalNotification(
              message.notification!.title ?? 'New Message',
              message.notification!.body ?? '',
              data: normalizedData,
              id: chatId?.hashCode,
            );
          }
        });
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _startListeningToFirestore(currentUser.uid);
        saveToken();
      }

      _authSubscription?.cancel();
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        user,
      ) {
        if (user != null) {
          _startListeningToFirestore(user.uid);
          saveToken();
        } else {
          _stopListeningToFirestore();
        }
      });
    } catch (e, stackTrace) {
      debugPrint("NotificationService init failed: $e");
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Fetches the FCM token and wires up token-refresh, retrying a
  /// bounded number of times with backoff on failure instead of giving
  /// up permanently after the first attempt.
  Future<void> _setUpFcmToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) _saveTokenToFirestore(token);

      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = _fcm.onTokenRefresh.listen(
        _saveTokenToFirestore,
      );

      _fcmRetryCount = 0;
    } catch (e, stackTrace) {
      debugPrint("FCM token/registration failed: $e");
      debugPrintStack(stackTrace: stackTrace);

      if (_fcmRetryCount < _maxFcmRetries) {
        _fcmRetryCount++;
        final delay = Duration(seconds: _fcmRetryCount * 5);
        _fcmRetryTimer?.cancel();
        _fcmRetryTimer = Timer(delay, _setUpFcmToken);
      } else {
        debugPrint(
          "FCM token setup: giving up after $_maxFcmRetries retries — "
          "push notifications via FCM will be unavailable, but "
          "Firestore-based in-app notifications will still work.",
        );
      }
    }
  }

  Future<void> _initLocalNotifications() async {
    if (_localNotificationsReady) return;

    try {
      final androidImplementation = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          'conexus_channel_id',
          'Conexus Messages',
          description: 'Notifications for new messages',
          importance: Importance.max,
          playSound: true,
        ),
      );

      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          'conexus_call_channel_id',
          'Conexus Calls',
          description: 'Notifications for incoming calls',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

      await androidImplementation?.requestNotificationsPermission();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        notificationCategories: [
          DarwinNotificationCategory(
            _iosMessageCategoryId,
            actions: [
              DarwinNotificationAction.text(
                'reply_action',
                'Reply',
                buttonTitle: 'Send',
                placeholder: 'Type your message...',
              ),
            ],
            options: {DarwinNotificationCategoryOption.customDismissAction},
          ),
          DarwinNotificationCategory(
            _iosCallCategoryId,
            actions: [
              DarwinNotificationAction.plain(
                'accept_call_action',
                'Accept',
                options: {DarwinNotificationActionOption.foreground},
              ),
              DarwinNotificationAction.plain(
                'decline_call_action',
                'Decline',
                options: {DarwinNotificationActionOption.destructive},
              ),
            ],
            options: {DarwinNotificationCategoryOption.customDismissAction},
          ),
        ],
      );

      await _localNotificationsPlugin.initialize(
        InitializationSettings(android: androidSettings, iOS: iosSettings),
        onDidReceiveNotificationResponse: _handleNotificationResponse,
        // FIX: on Android, any action WITHOUT `showsUserInterface: true`
        // (Reply and Decline here) is delivered to a background isolate
        // by the OS regardless of whether the app is currently running —
        // it never reaches `onDidReceiveNotificationResponse` above at
        // all. Without this callback registered, tapping Reply or
        // Decline was a silent no-op every time on Android, foreground
        // or not. Must be a top-level/static function — see
        // `notificationTapBackground` below.
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      _localNotificationsReady = true;

      // FIX (cold start replay safety net): on some plugin
      // versions/OEM Android builds, the tap that LAUNCHED the app
      // isn't reliably redelivered through `onDidReceiveNotificationResponse`
      // above. Explicitly check for it and route it through the same
      // handler — which is now safe to call this early because it
      // queues navigation via `_tryNavigateOrQueue` instead of
      // requiring `navigatorKey` to already be attached.
      try {
        final launchDetails = await _localNotificationsPlugin
            .getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp == true &&
            launchDetails?.notificationResponse != null) {
          debugPrint(
            "NotificationService: app was launched by a notification tap, replaying it",
          );
          _handleNotificationResponse(launchDetails!.notificationResponse!);
        }
      } catch (e) {
        debugPrint(
          "NotificationService: getNotificationAppLaunchDetails failed: $e",
        );
      }
    } catch (e, stackTrace) {
      debugPrint("Local notification init failed: $e");
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _startListeningToFirestore(String currentUserId) {
    debugPrint("NotificationService: Monitoring Firestore for $currentUserId");
    _currentListeningUid = currentUserId;
    _stopListeningToFirestore(clearUid: false);

    // MESSAGE MONITOR
    _messageSubscription = FirebaseFirestore.instance
        .collection('chat_rooms')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .listen(
          (snapshot) {
            for (var doc in snapshot.docs) {
              final data = doc.data();
              final roomId = doc.id;
              final lastMsg = data['lastMessage'] as String? ?? '';
              final lastMsgSenderId =
                  data['lastMessageSenderId'] as String? ?? '';
              final msgTime =
                  (data['lastMessageTime'] as Timestamp?) ?? Timestamp.now();

              if (lastMsgSenderId == currentUserId || lastMsg.isEmpty) continue;

              if (ChatScreen.activeChatUserId == lastMsgSenderId ||
                  GroupChatScreen.activeChatRoomId == roomId) {
                _lastMessageNotifiedTimes[roomId] = msgTime;
                continue;
              }

              final lastNotifiedTime = _lastMessageNotifiedTimes[roomId];
              if (lastNotifiedTime == null ||
                  msgTime.compareTo(lastNotifiedTime) > 0) {
                _lastMessageNotifiedTimes[roomId] = msgTime;
                final isGroup = data['isGroup'] == true;
                final names = Map<String, dynamic>.from(data['names'] ?? {});
                final title = isGroup
                    ? (data['groupName'] ?? 'Group Message')
                    : (names[lastMsgSenderId] ?? 'New Message');

                unawaited(_playMessageSound());
                _showLocalNotification(
                  title.toString(),
                  isGroup
                      ? "${names[lastMsgSenderId] ?? 'User'}: $lastMsg"
                      : lastMsg,
                  data: {
                    'chatId': roomId,
                    'senderId': lastMsgSenderId,
                    'isGroup': isGroup,
                  },
                  id: roomId.hashCode,
                );
              }
            }
            // A clean snapshot proves the listener is healthy again after any
            // earlier error — clear the restart guard so a future drop can
            // trigger a fresh restart.
            _isRestartingMessageListener = false;
          },
          onError: (e) {
            debugPrint("Message monitor error: $e");
            _restartMessageListener();
          },
        );

    // CALL MONITOR
    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: currentUserId)
        .snapshots()
        .listen(
          (snapshot) {
            _isRestartingCallListener = false;
            for (var doc in snapshot.docs) {
              final data = doc.data();
              final callId = doc.id;
              final status = data['status'] as String? ?? 'dialing';
              final callerId = data['callerId'] as String? ?? '';
              final timestamp = data['timestamp'] as Timestamp?;

              if (callerId == currentUserId) continue;
              if (timestamp != null &&
                  DateTime.now()
                          .difference(timestamp.toDate())
                          .abs()
                          .inMinutes >
                      5)
                continue;

              if (status == 'dialing') {
                if (!_processedCallIds.contains(callId)) {
                  _processedCallIds.add(callId);
                  try {
                    _handleIncomingCall(callId, data);
                  } catch (e, stackTrace) {
                    debugPrint("Error handling incoming call $callId: $e");
                    debugPrintStack(stackTrace: stackTrace);
                    _processedCallIds.remove(callId);
                  }
                }
              } else {
                if (_activeRingingCallId == callId) {
                  _stopRingtone();
                  _activeRingingCallId = null;
                }
                _localNotificationsPlugin.cancel(callId.hashCode);
                _processedCallIds.remove(callId);
              }
            }
          },
          onError: (e) {
            debugPrint("Call monitor error: $e");
            // Incoming-call detection is the most call-critical listener in
            // this service — a silent drop here means missed calls never
            // ring at all, so this restarts more aggressively than the
            // message monitor.
            _restartCallListener();
          },
        );
  }

  /// Restarts just the message-monitor half of Firestore listening for
  /// the currently signed-in user, without touching the call monitor.
  void _restartMessageListener() {
    if (_isRestartingMessageListener) return;
    final uid = _currentListeningUid;
    if (uid == null) return;
    _isRestartingMessageListener = true;

    Future.delayed(const Duration(seconds: 3), () {
      if (_currentListeningUid != uid)
        return; // user changed/signed out meanwhile
      _messageSubscription?.cancel();
      _messageSubscription = FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('participants', arrayContains: uid)
          .snapshots()
          .listen(
            (snapshot) {
              for (var doc in snapshot.docs) {
                final data = doc.data();
                final roomId = doc.id;
                final lastMsg = data['lastMessage'] as String? ?? '';
                final lastMsgSenderId =
                    data['lastMessageSenderId'] as String? ?? '';
                final msgTime =
                    (data['lastMessageTime'] as Timestamp?) ?? Timestamp.now();

                if (lastMsgSenderId == uid || lastMsg.isEmpty) continue;

                if (ChatScreen.activeChatUserId == lastMsgSenderId ||
                    GroupChatScreen.activeChatRoomId == roomId) {
                  _lastMessageNotifiedTimes[roomId] = msgTime;
                  continue;
                }

                final lastNotifiedTime = _lastMessageNotifiedTimes[roomId];
                if (lastNotifiedTime == null ||
                    msgTime.compareTo(lastNotifiedTime) > 0) {
                  _lastMessageNotifiedTimes[roomId] = msgTime;
                  final isGroup = data['isGroup'] == true;
                  final names = Map<String, dynamic>.from(data['names'] ?? {});
                  final title = isGroup
                      ? (data['groupName'] ?? 'Group Message')
                      : (names[lastMsgSenderId] ?? 'New Message');

                  unawaited(_playMessageSound());
                  _showLocalNotification(
                    title.toString(),
                    isGroup
                        ? "${names[lastMsgSenderId] ?? 'User'}: $lastMsg"
                        : lastMsg,
                    data: {
                      'chatId': roomId,
                      'senderId': lastMsgSenderId,
                      'isGroup': isGroup,
                    },
                    id: roomId.hashCode,
                  );
                }
              }
              _isRestartingMessageListener = false;
            },
            onError: (e) {
              debugPrint("Message monitor error (post-restart): $e");
              _isRestartingMessageListener = false;
              _restartMessageListener();
            },
          );
    });
  }

  /// Restarts just the call-monitor half of Firestore listening.
  void _restartCallListener() {
    if (_isRestartingCallListener) return;
    final uid = _currentListeningUid;
    if (uid == null) return;
    _isRestartingCallListener = true;

    Future.delayed(const Duration(seconds: 2), () {
      if (_currentListeningUid != uid) return;
      _callSubscription?.cancel();
      _callSubscription = FirebaseFirestore.instance
          .collection('calls')
          .where('receiverId', isEqualTo: uid)
          .snapshots()
          .listen(
            (snapshot) {
              _isRestartingCallListener = false;
              for (var doc in snapshot.docs) {
                final data = doc.data();
                final callId = doc.id;
                final status = data['status'] as String? ?? 'dialing';
                final callerId = data['callerId'] as String? ?? '';
                final timestamp = data['timestamp'] as Timestamp?;

                if (callerId == uid) continue;
                if (timestamp != null &&
                    DateTime.now()
                            .difference(timestamp.toDate())
                            .abs()
                            .inMinutes >
                        5)
                  continue;

                if (status == 'dialing') {
                  if (!_processedCallIds.contains(callId)) {
                    _processedCallIds.add(callId);
                    try {
                      _handleIncomingCall(callId, data);
                    } catch (e, stackTrace) {
                      debugPrint("Error handling incoming call $callId: $e");
                      debugPrintStack(stackTrace: stackTrace);
                      _processedCallIds.remove(callId);
                    }
                  }
                } else {
                  if (_activeRingingCallId == callId) {
                    _stopRingtone();
                    _activeRingingCallId = null;
                  }
                  _localNotificationsPlugin.cancel(callId.hashCode);
                  _processedCallIds.remove(callId);
                }
              }
            },
            onError: (e) {
              debugPrint("Call monitor error (post-restart): $e");
              _isRestartingCallListener = false;
              _restartCallListener();
            },
          );
    });
  }

  void _handleIncomingCall(String callId, Map<String, dynamic> data) {
    if (_activeCallDialogId != null) {
      debugPrint(
        "Ignoring incoming call $callId — dialog already showing for $_activeCallDialogId",
      );
      return;
    }

    final String callerId = data['callerId']?.toString() ?? '';
    final String callerName = data['callerName']?.toString() ?? 'User';
    final String callerImage = data['callerImage']?.toString() ?? '';
    final bool isVideo = data['isVideo'] == true;

    _activeRingingCallId = callId;
    unawaited(_startRingtone());
    _showCallNotification(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerImage: callerImage,
      isVideo: isVideo,
    );

    _tryNavigateOrQueue(() {
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      _activeCallDialogId = callId;
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
      ).then((_) {
        if (_activeCallDialogId == callId) _activeCallDialogId = null;
        if (_activeRingingCallId == callId) {
          _stopRingtone();
          _activeRingingCallId = null;
        }
      });
    });
  }

  Future<void> _startRingtone() async {
    try {
      _ringtonePlayer.audioCache.prefix = '';
      await _ringtonePlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.notificationRingtone,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
        ),
      );
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.play(AssetSource('assets/Sounds/ringtone.mp3'));
    } catch (e) {
      debugPrint("Error playing ringtone: $e");
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _ringtonePlayer.stop();
    } catch (e) {
      debugPrint("Error stopping ringtone: $e");
    }
  }

  Future<void> _playMessageSound() async {
    try {
      _messagePlayer.audioCache.prefix = '';
      await _messagePlayer.play(AssetSource('assets/Sounds/ringtone.mp3'));
      unawaited(
        Future.delayed(const Duration(seconds: 1), () => _messagePlayer.stop()),
      );
    } catch (e) {
      debugPrint("Error playing message sound: $e");
    }
  }

  void _stopListeningToFirestore({bool clearUid = true}) {
    _messageSubscription?.cancel();
    _callSubscription?.cancel();
    _messageSubscription = null;
    _callSubscription = null;
    _lastMessageNotifiedTimes.clear();
    _processedCallIds.clear();
    _activeRingingCallId = null;
    _activeCallDialogId = null;
    _isRestartingMessageListener = false;
    _isRestartingCallListener = false;
    // Avoid unbounded growth of the externally-resolved marker set once
    // this device stops monitoring calls for the current user.
    IncomingCallDialog.clearExternallyResolvedMarkers();
    if (clearUid) _currentListeningUid = null;
    _stopRingtone();
    _localNotificationsPlugin.cancelAll();
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
    unawaited(_stopRingtone());
    _activeRingingCallId = null;

    final payload = response.payload;
    if (payload == null) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(payload) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Malformed notification payload: $e");
      return;
    }

    if (response.actionId == 'accept_call_action') {
      final String? callId = data['callId']?.toString();
      final String? callerId = data['callerId']?.toString();
      final String? callerName = data['callerName']?.toString();
      final bool isVideo = data['isVideo'] == true || data['isVideo'] == 'true';

      if (callId != null && callerName != null) {
        try {
          final docRef = FirebaseFirestore.instance
              .collection('calls')
              .doc(callId);

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

          _localNotificationsPlugin.cancel(callId.hashCode);

          if (!joinable) {
            debugPrint("Call $callId is no longer joinable");
            return;
          }

          // FIX: mark this call as externally resolved BEFORE popping the
          // dialog. IncomingCallDialog has its own Firestore listener on
          // this same call doc — the transaction above just wrote
          // status: 'connected', which that listener will also observe.
          // Without this marker, both this code path AND the dialog's own
          // listener would race to pop the navigator: this path pops the
          // dialog then pushes VideoCallScreen, and a moment later the
          // dialog's listener sees 'connected' and pops *again*, tearing
          // down the freshly-pushed VideoCallScreen. Marking it first
          // tells the dialog's listener to stand down.
          IncomingCallDialog.markResolvedExternally(callId);
          _dismissActiveCallDialog(callId);

          // FIX (cold start / accept does nothing): previously this
          // read `navigatorKey.currentContext` directly and did nothing
          // if it was null — which is exactly what happens when this
          // whole handler fires during `_localNotificationsPlugin
          // .initialize()` in `init()`, i.e. before `runApp()` has
          // attached a Navigator. The transaction above still marked
          // the call 'connected' in that case, so the call would get
          // silently stuck with no screen ever shown. Now the push is
          // queued and flushed once the Navigator actually exists.
          _tryNavigateOrQueue(() {
            final context = navigatorKey.currentContext;
            if (context == null || !context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoCallScreen(
                  username: callerName,
                  isVideoEnabled: isVideo,
                  callId: callId,
                  isIncoming: true,
                  receiverId: callerId,
                ),
              ),
            );
          });
        } catch (e) {
          debugPrint("Error accepting call: $e");
        }
      }
    } else if (response.actionId == 'decline_call_action') {
      final String? callId = data['callId']?.toString();
      if (callId != null) {
        IncomingCallDialog.markResolvedExternally(callId);
        FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .update({'status': 'declined'})
            .catchError((e) => debugPrint("Error declining call: $e"));
        _localNotificationsPlugin.cancel(callId.hashCode);
        _dismissActiveCallDialog(callId);
      }
    } else if (response.actionId == 'reply_action' && response.input != null) {
      final chatId = _firstNonEmpty(data, _chatIdKeys);
      final senderId = _firstNonEmpty(data, _senderIdKeys);
      if (chatId != null && senderId != null) {
        await _sendReplyFromNotification(chatId, senderId, response.input!);
      } else {
        debugPrint(
          "Foreground reply: missing chatId/senderId after fallback lookup. "
          "payload keys were: ${data.keys.toList()}",
        );
      }
    } else {
      _navigateToTarget(data);
    }
  }

  void _dismissActiveCallDialog(String callId) {
    if (_activeCallDialogId != callId) return;
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
  }

  void _navigateToTarget(Map<String, dynamic> data) async {
    if (data['type'] == 'call') {
      final String callId = data['callId']?.toString() ?? '';
      if (callId.isEmpty) return;

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .get();
        final status = snapshot.data()?['status'] as String?;
        if (!snapshot.exists || status != 'dialing') {
          debugPrint(
            "Skipping stale call notification for $callId (status: $status)",
          );
          return;
        }
      } catch (e) {
        debugPrint("Error checking call status for $callId: $e");
        return;
      }

      if (_activeCallDialogId != null) return;

      _tryNavigateOrQueue(() {
        final context = navigatorKey.currentContext;
        if (context == null || !context.mounted) return;
        if (_activeCallDialogId != null) return;
        _activeCallDialogId = callId;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => IncomingCallDialog(
            callId: callId,
            callerId: data['callerId']?.toString() ?? '',
            callerName: data['callerName']?.toString() ?? 'User',
            callerImage: data['callerImage']?.toString() ?? '',
            isVideo: data['isVideo'] == true || data['isVideo'] == 'true',
          ),
        ).then((_) {
          if (_activeCallDialogId == callId) _activeCallDialogId = null;
          if (_activeRingingCallId == callId) {
            _stopRingtone();
            _activeRingingCallId = null;
          }
        });
      });
    } else if (data['senderId'] != null) {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(data['senderId'].toString())
          .get();
      if (!userSnap.exists) return;
      final userData = userSnap.data();
      _tryNavigateOrQueue(() {
        final context = navigatorKey.currentContext;
        if (context == null || !context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              receiverId: data['senderId'].toString(),
              username: userData?['name']?.toString() ?? 'User',
              profileImage: userData?['profileImage']?.toString() ?? '',
            ),
          ),
        );
      });
    }
  }

  Future<void> _sendReplyFromNotification(
    String chatId,
    String receiverId,
    String text,
  ) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    try {
      final now = FieldValue.serverTimestamp();
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
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatId)
          .set({
            'lastMessage': text,
            'lastMessageSenderId': currentUserId,
            'lastMessageTime': now,
            'unreadCount.$receiverId': FieldValue.increment(1),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error sending reply from notification: $e");
    }
  }

  void _saveTokenToFirestore(String token) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .set({'fcmToken': token}, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Error saving FCM token: $e");
      }
    }
  }

  void _showLocalNotification(
    String title,
    String body, {
    Map<String, dynamic>? data,
    int? id,
  }) async {
    if (!_localNotificationsReady) return;

    // DIAGNOSTIC: log the payload keys for message notifications so we
    // can confirm at the source whether a push-triggered notification
    // (data == message.data straight from FCM) is missing 'chatId' or
    // 'senderId' — that mismatch is the most likely reason Reply
    // silently drops for push-originated notifications while it works
    // for Firestore-listener-originated ones (which always build both
    // keys explicitly). Safe to remove once confirmed.
    if (data != null) {
      debugPrint(
        "NotificationService: showing local notification with payload keys: ${data.keys.toList()}",
      );
    }

    const androidDetails = AndroidNotificationDetails(
      'conexus_channel_id',
      'Conexus Messages',
      importance: Importance.max,
      priority: Priority.high,
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
    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: _iosMessageCategoryId,
    );
    try {
      await _localNotificationsPlugin.show(
        id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
        title,
        body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: data != null ? jsonEncode(data) : null,
      );
    } catch (e) {
      debugPrint("Error showing local notification: $e");
    }
  }

  void _showCallNotification({
    required String callId,
    required String callerId,
    required String callerName,
    required String callerImage,
    required bool isVideo,
  }) async {
    if (!_localNotificationsReady) return;

    final androidDetails = AndroidNotificationDetails(
      'conexus_call_channel_id',
      'Conexus Calls',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      actions: [
        const AndroidNotificationAction(
          'accept_call_action',
          'Accept',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction('decline_call_action', 'Decline'),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: _iosCallCategoryId,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    try {
      await _localNotificationsPlugin.show(
        callId.hashCode,
        isVideo ? "Incoming Video Call" : "Incoming Voice Call",
        "$callerName is calling...",
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode({
          'callId': callId,
          'callerId': callerId,
          'callerName': callerName,
          'callerImage': callerImage,
          'isVideo': isVideo,
          'type': 'call',
        }),
      );
    } catch (e) {
      debugPrint("Error showing call notification: $e");
    }
  }

  Future<void> dispose() async {
    _fcmRetryTimer?.cancel();
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _onMessageSubscription?.cancel();
    _stopListeningToFirestore();
    await _ringtonePlayer.dispose();
    await _messagePlayer.dispose();
  }
}

/// Handles a notification ACTION tap (Reply, Decline) that Android
/// delivers to a background isolate instead of the running app —
/// this happens for every action that isn't marked
/// `showsUserInterface: true`, REGARDLESS of whether the app is
/// currently foregrounded, backgrounded, or terminated. Must be a
/// top-level (or static) function, annotated `@pragma('vm:entry-point')`,
/// exactly like [firebaseMessagingBackgroundHandler] below — it runs in
/// its own isolate with no access to the running app's state.
@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  // DIAGNOSTIC: confirms the isolate actually spawned and shows exactly
  // which action fired and what payload it carried. If this line never
  // prints when you tap Reply/Decline, the background isolate isn't being
  // dispatched at all (check that `initialize()` — which registers this
  // callback — has run at least once since the app was installed).
  debugPrint(
    "notificationTapBackground: fired, actionId=${response.actionId}, "
    "hasInput=${response.input != null}, payload=${response.payload}",
  );

  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      // FIX: must match main.dart's Firebase.initializeApp call exactly.
      // A background isolate has no access to whatever implicit config
      // the main isolate resolved, so passing no options (or different
      // options) here was a silent-failure source.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("Background notification tap: Firebase init failed: $e");
  }

  // FIX: previously, a failed init above only logged and execution fell
  // through into FirebaseAuth/Firestore calls below. Those throw
  // `[core/no-app]` outside of any try/catch, silently killing this
  // isolate — which looked exactly like "reply/decline does nothing" from
  // the user's side, with zero indication why. Bail out explicitly and
  // loudly instead.
  if (Firebase.apps.isEmpty) {
    debugPrint(
      "Background notification tap: no Firebase app available, aborting",
    );
    return;
  }

  final payload = response.payload;
  if (payload == null) {
    debugPrint("Background notification tap: null payload, nothing to do");
    return;
  }

  Map<String, dynamic> data;
  try {
    data = jsonDecode(payload) as Map<String, dynamic>;
  } catch (e) {
    debugPrint("Background notification tap: malformed payload: $e");
    return;
  }

  if (response.actionId == 'decline_call_action') {
    final callId = data['callId']?.toString();
    if (callId == null || callId.isEmpty) {
      debugPrint(
        "Background decline: missing callId in payload, dropping. payload keys were: ${data.keys.toList()}",
      );
      return;
    }

    // FIX: mirror the reply branch below. A freshly-spun-up background
    // isolate may not have finished restoring the persisted Firebase Auth
    // session yet. If Firestore security rules for `calls/{callId}`
    // require `request.auth != null` (or check the caller's uid), firing
    // the update immediately — as this branch previously did — can hit
    // permission-denied before the session is ready. That failure was
    // being swallowed by the catch block below and only reached
    // debugPrint, which is invisible in a release build and looked
    // exactly like "decline does nothing."
    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      debugPrint(
        "Background decline: no current user yet, waiting on authStateChanges()",
      );
      try {
        currentUserId = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 5))
            .then((u) => u?.uid);
      } catch (e) {
        debugPrint("Background decline: auth state didn't restore in time: $e");
      }
    }
    if (currentUserId == null) {
      debugPrint(
        "Background decline: no authenticated user, dropping decline for call $callId",
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('calls').doc(callId).update({
        'status': 'declined',
      });
      debugPrint("Background decline: call $callId declined successfully");
    } catch (e) {
      debugPrint("Background decline failed for call $callId: $e");
    }
    try {
      await FlutterLocalNotificationsPlugin().cancel(callId.hashCode);
    } catch (_) {
      // best-effort
    }
    return;
  }

  if (response.actionId == 'reply_action') {
    final input = response.input?.trim();
    if (input == null || input.isEmpty) {
      debugPrint("Background reply: empty input, nothing to send");
      return;
    }

    // FIX: try the canonical keys first, then fall back through common
    // variants (roomId/room_id, sender_id/from, etc.) — see
    // _firstNonEmpty/_chatIdKeys/_senderIdKeys above. The onMessage
    // handler now normalizes these up front for push-originated
    // notifications, but this fallback also covers any notification
    // payload that reaches this isolate unnormalized.
    final chatId = _firstNonEmpty(data, _chatIdKeys);
    final receiverId = _firstNonEmpty(data, _senderIdKeys);
    if (chatId == null || receiverId == null) {
      // DIAGNOSTIC: this is the most likely culprit for "reply doesn't
      // send" if it still fires after the normalization fix above — it
      // means the payload doesn't carry ANY of the known variants for
      // chatId or senderId. Check the printed keys against what your
      // backend actually sends and add the real key name to
      // _chatIdKeys/_senderIdKeys near the top of this file.
      debugPrint(
        "Background reply: missing chatId/senderId in payload (checked $_chatIdKeys / "
        "$_senderIdKeys), dropping reply. payload keys were: ${data.keys.toList()}",
      );
      return;
    }

    // A freshly-spun-up background isolate may not have finished
    // restoring the persisted Firebase Auth session yet — give it a
    // short window rather than dropping the reply outright.
    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      debugPrint(
        "Background reply: no current user yet, waiting on authStateChanges()",
      );
      try {
        currentUserId = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 5))
            .then((u) => u?.uid);
      } catch (e) {
        debugPrint("Background reply: auth state didn't restore in time: $e");
      }
    }
    if (currentUserId == null) {
      debugPrint("Background reply: no authenticated user, dropping reply");
      return;
    }

    try {
      final now = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatId)
          .collection('messages')
          .add({
            'text': input,
            'imageUrl': '',
            'type': 'text',
            'status': 'sent',
            'isEdited': false,
            'senderId': currentUserId,
            'receiverId': receiverId,
            'time': now,
            'reactions': {},
          });
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatId)
          .set({
            'lastMessage': input,
            'lastMessageSenderId': currentUserId,
            'lastMessageTime': now,
            'unreadCount.$receiverId': FieldValue.increment(1),
          }, SetOptions(merge: true));
      debugPrint("Background reply: sent successfully to chat $chatId");
    } catch (e) {
      debugPrint("Background reply failed: $e");
    }
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("Background handler: Firebase init failed: $e");
  }

  if (Firebase.apps.isEmpty) {
    debugPrint("Background handler: no Firebase app available, aborting");
    return;
  }

  debugPrint(
    "NotificationService: Handling background message: ${message.messageId}",
  );

  final data = message.data;
  final type = data['type'];

  if (type == 'call_status') {
    final callId = data['callId']?.toString() ?? '';
    final status = data['status']?.toString();
    if (callId.isEmpty) return;
    if (status == 'cancelled' ||
        status == 'declined' ||
        status == 'ended' ||
        status == 'connected') {
      try {
        final plugin = FlutterLocalNotificationsPlugin();
        await plugin.cancel(callId.hashCode);
      } catch (e) {
        debugPrint(
          "Background handler: failed to cancel stale call notification: $e",
        );
      }
    }
    return;
  }

  if (type != 'call') return;

  final plugin = FlutterLocalNotificationsPlugin();

  try {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final iosSettings = DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          'call_category',
          actions: [
            DarwinNotificationAction.plain(
              'accept_call_action',
              'Accept',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              'decline_call_action',
              'Decline',
              options: {DarwinNotificationActionOption.destructive},
            ),
          ],
          options: {DarwinNotificationCategoryOption.customDismissAction},
        ),
      ],
    );
    // FIX: this MUST register the same onDidReceiveNotificationResponse /
    // onDidReceiveBackgroundNotificationResponse callbacks that
    // NotificationService._initLocalNotifications() registers. On Android,
    // flutter_local_notifications persists the background-tap dispatcher
    // as a callback handle stored natively (via PluginUtilities
    // .getCallbackHandle) — it is NOT scoped to this particular plugin
    // instance or isolate. Whichever initialize() call runs most recently
    // ON THE DEVICE wins. This handler runs in its own background isolate
    // every time a 'call' push arrives, which in practice can happen more
    // recently than the app's own startup init — so calling initialize()
    // here without these callbacks was silently overwriting the real
    // registration and breaking Accept/Reply/Decline taps until the next
    // full app restart re-ran NotificationService.init(). Must stay in
    // sync with the registration in _initLocalNotifications() above.
    await plugin.initialize(
      InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidImplementation = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        'conexus_call_channel_id',
        'Conexus Calls',
        description: 'Notifications for incoming calls',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    final callId = data['callId']?.toString() ?? '';
    final callerId = data['callerId']?.toString() ?? '';
    final callerName = data['callerName']?.toString() ?? 'User';
    final callerImage = data['callerImage']?.toString() ?? '';
    final isVideo = data['isVideo'] == true || data['isVideo'] == 'true';

    if (callId.isEmpty) return;

    final androidDetails = AndroidNotificationDetails(
      'conexus_call_channel_id',
      'Conexus Calls',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      actions: [
        const AndroidNotificationAction(
          'accept_call_action',
          'Accept',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction('decline_call_action', 'Decline'),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'call_category',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await plugin.show(
      callId.hashCode,
      isVideo ? "Incoming Video Call" : "Incoming Voice Call",
      "$callerName is calling...",
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode({
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'callerImage': callerImage,
        'isVideo': isVideo,
        'type': 'call',
      }),
    );
  } catch (e, stackTrace) {
    debugPrint("Background handler: failed to show call notification: $e");
    debugPrintStack(stackTrace: stackTrace);
  }
}
