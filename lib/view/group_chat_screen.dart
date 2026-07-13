import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:conexus/viewmodel/user_view_model.dart';

class GroupChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String groupName;
  final String groupImage;

  static String? activeChatRoomId;

  const GroupChatScreen({
    super.key,
    required this.chatRoomId,
    required this.groupName,
    required this.groupImage,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  @override
  void initState() {
    super.initState();
    GroupChatScreen.activeChatRoomId = widget.chatRoomId;
  }

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;
  bool _isSendingMessage = false;
  Timer? _typingTimer;
  bool _isTypingNotified = false;
  Map<String, dynamic>? _replyMessage;
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  // Tracks the doc count from the last snapshot so we only auto-scroll when
  // a message is actually added/removed — not on every reaction, edit, or
  // typing-status change that also comes through this stream's parent doc.
  int _lastMessageCount = 0;

  void _scrollToMessage(String? messageId) {
    if (messageId == null || !_messageKeys.containsKey(messageId)) return;

    final ctx = _messageKeys[messageId]!.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      setState(() => _highlightedMessageId = messageId);
      Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightedMessageId = null);
      });
    }
  }

  Future<void> sendMessage({String? text, String? imageUrl, String type = 'text'}) async {
    final msgText = text ?? messageController.text.trim();
    if (msgText.isEmpty && imageUrl == null) return;
    if (_isSendingMessage) return; // guard against double-tap / double-submit

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    setState(() => _isSendingMessage = true);

    final viewModel = context.read<UserViewModel>();
    final senderName = viewModel.user?.name ?? FirebaseAuth.instance.currentUser?.email ?? 'User';
    final senderImage = viewModel.user?.profileImage ?? 'https://i.pravatar.cc/150?u=$currentUserId';

    final replyData = _replyMessage;
    setState(() => _replyMessage = null);

    if (type == 'text') {
      messageController.clear();
    }

    try {
      final now = FieldValue.serverTimestamp();

      final messageRef = FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .doc();

      await messageRef.set({
        'text': msgText,
        'imageUrl': imageUrl ?? '',
        'type': type,
        'status': 'sent',
        'isEdited': false,
        'senderId': currentUserId,
        'senderName': senderName, // Groups need to display who sent it
        'senderImage': senderImage,
        'time': now,
        'reactions': {},
        'replyTo': replyData,
      });

      // We don't update names and profile images here, just last message
      await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.chatRoomId).set({
        'lastMessage': type == 'images' ? '📷 images' : '$senderName: $msgText',
        'lastMessageSenderId': currentUserId,
        'lastMessageTime': now,
      }, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }

    if (!mounted) return;
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_isUploadingImage) return;

    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.jpg';
      final ref = FirebaseStorage.instance.ref().child('chat_images').child(fileName);

      final file = File(image.path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});

      if (snapshot.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        await sendMessage(text: '', imageUrl: downloadUrl, type: 'images');
      } else {
        throw Exception("Upload failed with state: ${snapshot.state}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('images Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _setTypingStatus(String userId, bool isTyping) {
    FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.chatRoomId)
        .update({'typing_status.$userId': isTyping}).catchError((_) {});
  }

  void _onTyping(String value) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    if (value.isEmpty) {
      // Field cleared — report "not typing" right away instead of waiting
      // out the debounce window.
      _typingTimer?.cancel();
      if (_isTypingNotified) {
        _isTypingNotified = false;
        _setTypingStatus(currentUserId, false);
      }
      return;
    }

    // Only write "typing" once per burst, not on every keystroke — this was
    // previously firing a Firestore update on every character typed.
    if (!_isTypingNotified) {
      _isTypingNotified = true;
      _setTypingStatus(currentUserId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTypingNotified = false;
      _setTypingStatus(currentUserId, false);
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted || !scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final amPm = date.hour >= 12 ? "PM" : "AM";
    return "$hour:${date.minute.toString().padLeft(2, '0')} $amPm";
  }

  void _showMessageOptions(String docId, Map<String, dynamic> data) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final senderId = data['senderId']?.toString() ?? '';
    final isMe = currentUserId == senderId;
    final type = data['type']?.toString() ?? 'text';
    final senderName = data['senderName']?.toString() ?? 'User';

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
                      'text': data['type'] == 'images' ? '📷 images' : (data['text'] ?? ''),
                      'senderName': isMe ? 'You' : senderName,
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(widget.chatRoomId)
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.chatRoomId)
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
                  FirebaseFirestore.instance
                      .collection('chat_rooms')
                      .doc(widget.chatRoomId)
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

  @override
  void dispose() {
    if (GroupChatScreen.activeChatRoomId == widget.chatRoomId) {
      GroupChatScreen.activeChatRoomId = null;
    }

    _typingTimer?.cancel();

    // Best-effort: if we left while still "typing", clear the flag so other
    // members don't see a stale typing indicator forever.
    if (_isTypingNotified) {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (currentUserId.isNotEmpty) {
        FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(widget.chatRoomId)
            .update({'typing_status.$currentUserId': false}).catchError((_) {});
      }
    }

    messageController.dispose();
    scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: widget.groupImage.isNotEmpty ? NetworkImage(widget.groupImage) : null,
              onBackgroundImageError: widget.groupImage.isNotEmpty ? (_, __) {} : null,
              child: widget.groupImage.isEmpty ? const Icon(Icons.group) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.groupName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text("Group", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(widget.chatRoomId)
                  .collection('messages')
                  .orderBy('time', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                }

                final docs = snapshot.data?.docs ?? [];

                // Only auto-scroll when the message count actually changed
                // (new message sent/received, or one removed) — not on
                // every snapshot update, so reactions/edits on messages
                // above don't yank the view back down while someone is
                // reading older messages.
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
                    final text = data['text']?.toString() ?? '';
                    final imageUrl = data['imageUrl']?.toString() ?? '';
                    final type = data['type']?.toString() ?? 'text';
                    final senderId = data['senderId']?.toString() ?? '';
                    final senderName = data['senderName']?.toString() ?? 'User';
                    final senderImage = data['senderImage']?.toString() ?? '';
                    final timestamp = data['time'] as Timestamp?;
                    final isEdited = data['isEdited'] as bool? ?? false;
                    final isMe = senderId == currentUserId;
                    final isSystem = type == 'system';
                    final replyTo = data['replyTo'] as Map<String, dynamic>?;

                    if (!_messageKeys.containsKey(doc.id)) {
                      _messageKeys[doc.id] = GlobalKey();
                    }

                    if (isSystem) {
                      return Center(
                        key: _messageKeys[doc.id],
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ),
                      );
                    }

                    return Align(
                      key: _messageKeys[doc.id],
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: senderImage.isNotEmpty ? NetworkImage(senderImage) : null,
                              onBackgroundImageError: senderImage.isNotEmpty ? (_, __) {} : null,
                              child: senderImage.isEmpty ? const Icon(Icons.person, size: 14) : null,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                                  child: Text(senderName, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                ),
                              GestureDetector(
                                onLongPress: () => _showMessageOptions(doc.id, data),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: type == 'images'
                                      ? const EdgeInsets.all(4)
                                      : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  constraints: const BoxConstraints(maxWidth: 260),
                                  decoration: BoxDecoration(
                                    color: _highlightedMessageId == doc.id
                                        ? Colors.orange.withValues(alpha: 0.3)
                                        : (isMe ? Colors.orange : Theme.of(context).cardColor),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
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
                                      type == 'images'
                                          ? ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.broken_image),
                                        ),
                                      )
                                          : Text(
                                        text,
                                        style: TextStyle(
                                          color: isMe ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12, left: 6, right: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isEdited) ...[
                                      Text('Edited',
                                          style: TextStyle(
                                              color: Colors.grey.shade500, fontSize: 10, fontStyle: FontStyle.italic)),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      formatTimestamp(timestamp),
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_isUploadingImage)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(color: Colors.orange),
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
                    child: Text(
                      "Replying to ${_replyMessage!['senderName']}\n${_replyMessage!['text']}",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _replyMessage = null),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.orange),
                  onPressed: _isUploadingImage ? null : () => _pickAndSendImage(ImageSource.gallery),
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.orange),
                  onPressed: _isUploadingImage ? null : () => _pickAndSendImage(ImageSource.camera),
                ),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    onChanged: _onTyping,
                    cursorColor: Colors.orange,
                    onSubmitted: (_) => sendMessage(),
                    decoration: InputDecoration(
                      hintText: "Type message...",
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isSendingMessage ? null : () => sendMessage(),
                  child: Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: _isSendingMessage ? Colors.orange.withValues(alpha: 0.5) : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}