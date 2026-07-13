import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:conexus/services/cloudinary_service.dart';
import 'video_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String username;
  final String profileImage;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  static String? activeChatUserId;

  ChatScreen({
    super.key,
    required this.receiverId,
    required this.username,
    required this.profileImage,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Computed once — the current user and the derived room id don't change
  // for the lifetime of this screen, so there's no need to re-derive them
  // (and re-touch FirebaseAuth) in every handler.
  late final String currentUserId;
  late final String chatRoomId;

  @override
  void initState() {
    super.initState();
    ChatScreen.activeChatUserId = widget.receiverId;
    currentUserId = widget.auth.currentUser?.uid ?? '';
    chatRoomId = getChatRoomId(currentUserId, widget.receiverId);
  }

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isSendingMessage = false;
  bool _isCallDialing = false;
  Timer? _typingTimer;
  bool _isTypingNotified = false;
  Map<String, dynamic>? _replyMessage;

  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  // Tracks the last seen message count so we only auto-scroll when a
  // message is actually added/removed, not on every snapshot (reactions,
  // edits, read-status changes all come through the same stream).
  int _lastMessageCount = 0;

  String getChatRoomId(String uid1, String uid2) {
    final list = [uid1, uid2];
    list.sort();
    return "${list[0]}_${list[1]}";
  }

  void _scrollToMessage(String? messageId) {
    if (messageId == null || !_messageKeys.containsKey(messageId)) return;

    final targetContext = _messageKeys[messageId]!.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      setState(() => _highlightedMessageId = messageId);
      Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightedMessageId = null);
      });
    }
  }

  Future<void> sendMessage(
      {String? text, String? imageUrl, String type = 'text', bool isForwarded = false}) async {
    final msgText = text ?? messageController.text.trim();
    if (msgText.isEmpty && imageUrl == null && type != 'call') return;
    if (currentUserId.isEmpty) return;
    if (_isSendingMessage) return; // guard against double-tap / double-submit

    setState(() => _isSendingMessage = true);

    final viewModel = context.read<UserViewModel>();
    final senderName = viewModel.user?.name ?? widget.auth.currentUser?.email ?? 'User';
    final senderImage = viewModel.user?.profileImage ?? 'https://i.pravatar.cc/150?u=$currentUserId';

    final replyData = _replyMessage;
    setState(() => _replyMessage = null);

    if (type == 'text' && !isForwarded) {
      messageController.clear();
    }

    try {
      final now = FieldValue.serverTimestamp();

      final messageRef =
      widget.firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').doc();

      await messageRef.set({
        'text': msgText,
        'imageUrl': imageUrl ?? '',
        'type': type,
        'status': 'sent',
        'isEdited': false,
        'isForwarded': isForwarded,
        'senderId': currentUserId,
        'receiverId': widget.receiverId,
        'time': now,
        'reactions': {},
        'replyTo': replyData,
      });

      String lastMsgDisplay = msgText;
      if (type == 'images') {
        lastMsgDisplay = '📷 images';
      } else if (type == 'video') {
        lastMsgDisplay = '🎥 Video';
      } else if (type == 'file') {
        lastMsgDisplay = '📁 $msgText';
      } else if (isForwarded) {
        lastMsgDisplay = 'Forwarded: $msgText';
      }

      await widget.firestore.collection('chat_rooms').doc(chatRoomId).set({
        'participants': [currentUserId, widget.receiverId],
        'lastMessage': lastMsgDisplay,
        'lastMessageSenderId': currentUserId,
        'lastMessageTime': now,
        'names': {
          currentUserId: senderName,
          widget.receiverId: widget.username,
        },
        'profileImages': {
          currentUserId: senderImage,
          widget.receiverId: widget.profileImage,
        },
        'unreadCount.${widget.receiverId}': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }

    if (!mounted) return;
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_isUploading) return;

    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(image.path);
      final downloadUrl = await CloudinaryService.uploadImage(file);

      if (downloadUrl != null) {
        await sendMessage(text: '', imageUrl: downloadUrl, type: 'images');
      } else {
        throw Exception("Upload failed");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('images Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickAndSendVideo() async {
    if (_isUploading) return;

    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(video.path);
      final downloadUrl = await CloudinaryService.uploadVideo(file);

      if (downloadUrl != null) {
        await sendMessage(text: '', imageUrl: downloadUrl, type: 'video');
      } else {
        throw Exception("Upload failed");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    if (_isUploading) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.single.path == null) return;

      setState(() => _isUploading = true);

      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;
      final file = File(filePath);

      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_files')
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});

      if (snapshot.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        await sendMessage(text: fileName, imageUrl: downloadUrl, type: 'file');
      } else {
        throw Exception("File upload failed");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAttachmentOptions() {
    if (_isUploading) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.orange),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.orange),
                title: const Text('Gallery (Photo)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.orange),
                title: const Text('Video'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendVideo();
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file, color: Colors.orange),
                title: const Text('Document / File'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessageOptions(String docId, Map<String, dynamic> data) {
    final senderId = data['senderId']?.toString() ?? '';
    final isMe = currentUserId == senderId;
    final type = data['type']?.toString() ?? 'text';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['❤️', '👍', '🔥', '😂', '😮', '😢'].map((emoji) {
                  return InkWell(
                    onTap: () {
                      _reactToMessage(docId, emoji);
                      Navigator.pop(context);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  );
                }).toList(),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.reply, color: Colors.blue),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyMessage = {
                      'messageId': docId,
                      'text': data['type'] == 'images'
                          ? '📷 images'
                          : (data['type'] == 'video'
                          ? '🎥 Video'
                          : (data['type'] == 'file' ? '📁 ${data['text']}' : (data['text'] ?? ''))),
                      'senderName': isMe ? 'You' : widget.username,
                    };
                  });
                },
              ),
              if (isMe && type == 'text')
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Edit Message'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(docId, data['text']?.toString() ?? '');
                  },
                ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Message'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteMessage(docId);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteMessage(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              widget.firestore
                  .collection('chat_rooms')
                  .doc(chatRoomId)
                  .collection('messages')
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _reactToMessage(String docId, String emoji) {
    widget.firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(docId)
        .set({
      'reactions': {currentUserId: emoji}
    }, SetOptions(merge: true));
  }

  void _showEditDialog(String docId, String currentText) {
    final TextEditingController editController = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(controller: editController, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final newText = editController.text.trim();
                if (newText.isNotEmpty && newText != currentText) {
                  widget.firestore
                      .collection('chat_rooms')
                      .doc(chatRoomId)
                      .collection('messages')
                      .doc(docId)
                      .update({'text': newText, 'isEdited': true});
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _markAsReadIfNeeded(List<QueryDocumentSnapshot> docs) {
    if (currentUserId.isEmpty) return;
    bool needsUpdate = false;
    final batch = widget.firestore.batch();

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['senderId'] == widget.receiverId && data['status'] != 'read') {
        batch.update(doc.reference, {'status': 'read'});
        needsUpdate = true;
      }
    }

    if (needsUpdate) {
      batch.commit();
      widget.firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .update({'unreadCount.$currentUserId': 0}).catchError((_) {});
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted || !scrollController.hasClients) return;
      scrollController.animateTo(scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    return "$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? "PM" : "AM"}";
  }

  void _setTypingStatus(bool isTyping) {
    // set+merge (not update) — `update` throws if the chat_room doc doesn't
    // exist yet, which is exactly the case the first time two people chat
    // and one starts typing before either has sent a message.
    widget.firestore.collection('chat_rooms').doc(chatRoomId).set({
      'typing_status': {currentUserId: isTyping}
    }, SetOptions(merge: true)).catchError((_) {});
  }

  void _onTyping(String value) {
    if (currentUserId.isEmpty) return;

    if (value.isEmpty) {
      _typingTimer?.cancel();
      if (_isTypingNotified) {
        _isTypingNotified = false;
        _setTypingStatus(false);
      }
      return;
    }

    // Only announce "typing" once per burst, not on every keystroke.
    if (!_isTypingNotified) {
      _isTypingNotified = true;
      _setTypingStatus(true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTypingNotified = false;
      _setTypingStatus(false);
    });
  }

  @override
  void dispose() {
    if (ChatScreen.activeChatUserId == widget.receiverId) {
      ChatScreen.activeChatUserId = null;
    }
    _typingTimer?.cancel();
    if (_isTypingNotified) {
      _setTypingStatus(false);
    }
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _initiateCall(BuildContext context, {required bool isVideo}) async {
    if (_isCallDialing || currentUserId.isEmpty) return;
    setState(() => _isCallDialing = true);

    try {
      final viewModel = context.read<UserViewModel>();
      final senderName = viewModel.user?.name ?? widget.auth.currentUser?.email ?? 'User';
      final senderImage = viewModel.user?.profileImage ?? 'https://i.pravatar.cc/150?u=$currentUserId';

      final callDoc = widget.firestore.collection('calls').doc();
      final callId = callDoc.id;

      await callDoc.set({
        'callId': callId,
        'callerId': currentUserId,
        'callerName': senderName,
        'callerImage': senderImage,
        'receiverId': widget.receiverId,
        'receiverName': widget.username,
        'receiverImage': widget.profileImage,
        'isVideo': isVideo,
        'status': 'dialing',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoCallScreen(
              username: widget.username,
              isVideoEnabled: isVideo,
              callId: callId,
              isIncoming: false,
              receiverId: widget.receiverId,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCallDialing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios)),
        title: StreamBuilder<DocumentSnapshot>(
          stream: widget.firestore.collection('users').doc(widget.receiverId).snapshots(),
          builder: (context, userSnapshot) {
            bool isOnline = userSnapshot.hasData && (userSnapshot.data?.data() as Map?)?['isOnline'] == true;
            return Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: widget.profileImage.isNotEmpty ? NetworkImage(widget.profileImage) : null,
                  onBackgroundImageError: widget.profileImage.isNotEmpty ? (_, __) {} : null,
                  child: widget.profileImage.isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.username, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(isOnline ? "Online" : "Offline",
                        style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.orange),
            onPressed: _isCallDialing ? null : () => _initiateCall(context, isVideo: false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.orange),
            onPressed: _isCallDialing ? null : () => _initiateCall(context, isVideo: true),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.firestore
                  .collection('chat_rooms')
                  .doc(chatRoomId)
                  .collection('messages')
                  .orderBy('time', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                WidgetsBinding.instance.addPostFrameCallback((_) => _markAsReadIfNeeded(docs));

                // Auto-scroll to the newest message when the count changes
                // (mine or theirs), but not on reaction/edit/read updates
                // that don't add or remove a message.
                if (docs.length != _lastMessageCount) {
                  _lastMessageCount = docs.length;
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                }

                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == currentUserId;
                    final replyToRaw = data['replyTo'];
                    final replyTo = replyToRaw is Map ? Map<String, dynamic>.from(replyToRaw) : null;
                    final reactionsRaw = data['reactions'];
                    final reactions = reactionsRaw is Map ? Map<String, dynamic>.from(reactionsRaw) : null;

                    if (!_messageKeys.containsKey(doc.id)) {
                      _messageKeys[doc.id] = GlobalKey();
                    }

                    return Align(
                      key: _messageKeys[doc.id],
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onLongPress: () => _showMessageOptions(doc.id, data),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              padding: (data['type'] == 'images' || data['type'] == 'video')
                                  ? const EdgeInsets.all(4)
                                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _highlightedMessageId == doc.id
                                    ? Colors.orange.withValues(alpha: 0.3)
                                    : (isMe ? Colors.orange : Theme.of(context).cardColor),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (replyTo != null)
                                    GestureDetector(
                                      onTap: () => _scrollToMessage(replyTo['messageId']),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(replyTo['senderName'] ?? '',
                                                style: const TextStyle(
                                                    fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                                            Text(replyTo['text'] ?? '',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (data['type'] == 'images')
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.network(
                                        data['imageUrl'] ?? '',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                                      ),
                                    )
                                  else if (data['type'] == 'video')
                                    InkWell(
                                      onTap: () async {
                                        final url = data['imageUrl'] ?? '';
                                        if (url.isNotEmpty) {
                                          final uri = Uri.parse(url);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                                          }
                                        }
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          color: Colors.black12,
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            const Icon(Icons.video_library, size: 100, color: Colors.orange),
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                              child: const Icon(Icons.play_arrow, size: 30, color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else if (data['type'] == 'call')
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            data['text'] == 'Missed Call' ? Icons.call_missed : Icons.call_made,
                                            color: data['text'] == 'Missed Call' ? Colors.red : Colors.grey,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            data['text'] ?? '',
                                            style: TextStyle(
                                              color: data['text'] == 'Missed Call' ? Colors.red : (isMe ? Colors.white : null),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      )
                                    else if (data['type'] == 'file')
                                        InkWell(
                                          onTap: () async {
                                            final url = data['imageUrl'] ?? '';
                                            if (url.isNotEmpty) {
                                              final uri = Uri.parse(url);
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                                              } else {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Could not open file URL')),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.2),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.insert_drive_file,
                                                  color: isMe ? Colors.white : Colors.orange,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      data['text'] ?? 'File',
                                                      style: TextStyle(
                                                        color: isMe ? Colors.white : null,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      'Tap to open',
                                                      style: TextStyle(
                                                        color: isMe ? Colors.white70 : Colors.black54,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Text(data['text'] ?? '', style: TextStyle(color: isMe ? Colors.white : null)),
                                ],
                              ),
                            ),
                          ),
                          if (reactions != null && reactions.isNotEmpty)
                            Positioned(
                              bottom: -4,
                              right: isMe ? null : 10,
                              left: isMe ? 10 : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, spreadRadius: 1)
                                  ],
                                ),
                                child: Text(
                                  reactions.values.toSet().join(''),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_replyMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).cardColor,
              child: Row(
                children: [
                  const Icon(Icons.reply, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text("Replying to ${_replyMessage!['senderName']}\n${_replyMessage!['text']}",
                          maxLines: 2, overflow: TextOverflow.ellipsis)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _replyMessage = null)),
                ],
              ),
            ),
          if (_isUploading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Uploading attachment...",
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    onChanged: _onTyping,
                    onSubmitted: (_) => sendMessage(),
                    decoration: InputDecoration(
                      hintText: "Type message...",
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.add, color: Colors.orange),
                        onPressed: _showAttachmentOptions,
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: _isSendingMessage ? Colors.orange.withValues(alpha: 0.5) : Colors.orange),
                  onPressed: _isSendingMessage ? null : () => sendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
