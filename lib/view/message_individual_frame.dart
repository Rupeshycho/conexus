import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:conexus/model/user_model.dart';
import 'video_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String username;
  final String profileImage;
git
  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.username,
    required this.profileImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;
  Timer? _typingTimer;

  String getChatRoomId(String uid1, String uid2) {
    final list = [uid1, uid2];
    list.sort();
    return "${list[0]}_${list[1]}";
  }

  void sendMessage({String? text, String? imageUrl, String type = 'text', bool isForwarded = false}) async {
    final msgText = text ?? messageController.text.trim();
    if (msgText.isEmpty && imageUrl == null) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    final viewModel = context.read<UserViewModel>();
    final senderName = viewModel.user?.name ?? FirebaseAuth.instance.currentUser?.email ?? 'User';
    final senderImage = viewModel.user?.profileImage ?? 'https://i.pravatar.cc/150?u=$currentUserId';

    final chatRoomId = getChatRoomId(currentUserId, widget.receiverId);

    if (type == 'text' && !isForwarded) {
      messageController.clear();
    }

    final now = FieldValue.serverTimestamp();

    // 1. Add message to the subcollection
    final messageRef = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc();

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
    });

    // 2. Set/update the parent chat room info
    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId)
        .set({
      'participants': [currentUserId, widget.receiverId],
      'lastMessage': type == 'image' ? '📷 Image' : (isForwarded ? 'Forwarded: $msgText' : msgText),
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

    _scrollToBottom();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.jpg';
      final ref = FirebaseStorage.instance.ref().child('chat_images').child(fileName);

      final file = File(image.path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});

      if (snapshot.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        sendMessage(text: '', imageUrl: downloadUrl, type: 'image');
      } else {
        throw Exception("Upload failed with state: ${snapshot.state}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  void _showMessageOptions(String docId, Map<String, dynamic> data) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final senderId = data['senderId']?.toString() ?? '';
    final isMe = currentUserId == senderId;
    final type = data['type']?.toString() ?? 'text';
    final chatRoomId = getChatRoomId(currentUserId, widget.receiverId);

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
              const SizedBox(height: 12),
              // Reaction Bar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
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
              ),
              const Divider(),
              if (isMe && type == 'text')
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Edit Message'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(docId, data['text']?.toString() ?? '', chatRoomId);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.forward, color: Colors.green),
                title: const Text('Forward Message'),
                onTap: () {
                  Navigator.pop(context);
                  _showForwardDialog(data);
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Message'),
                  onTap: () {
                    FirebaseFirestore.instance
                        .collection('chat_rooms')
                        .doc(chatRoomId)
                        .collection('messages')
                        .doc(docId)
                        .delete();
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _reactToMessage(String docId, String emoji) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final chatRoomId = getChatRoomId(currentUserId, widget.receiverId);

    FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(docId)
        .set({
      'reactions': {
        currentUserId: emoji
      }
    }, SetOptions(merge: true));
  }

  void _showForwardDialog(Map<String, dynamic> messageData) {
    final viewModel = context.read<UserViewModel>();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Forward to'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: viewModel.allUsers?.length ?? 0,
              itemBuilder: (context, index) {
                final user = viewModel.allUsers![index];
                if (user.id == FirebaseAuth.instance.currentUser?.uid) return const SizedBox.shrink();
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(user.profileImage.isNotEmpty ? user.profileImage : 'https://i.pravatar.cc/150?u=${user.id}'),
                  ),
                  title: Text(user.name),
                  onTap: () {
                    _forwardToUser(user, messageData);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Message forwarded to ${user.name}')),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _forwardToUser(UserModel user, Map<String, dynamic> data) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final chatRoomId = getChatRoomId(currentUserId, user.id);
    final now = FieldValue.serverTimestamp();

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add({
      'text': data['text'] ?? '',
      'imageUrl': data['imageUrl'] ?? '',
      'type': data['type'] ?? 'text',
      'status': 'sent',
      'isEdited': false,
      'isForwarded': true,
      'senderId': currentUserId,
      'receiverId': user.id,
      'time': now,
      'reactions': {},
    });

    // Update parent chat room info for the recipient
    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId)
        .set({
      'participants': [currentUserId, user.id],
      'lastMessage': data['type'] == 'image' ? '📷 Forwarded Image' : 'Forwarded: ${data['text']}',
      'lastMessageSenderId': currentUserId,
      'lastMessageTime': now,
      'names': {
        currentUserId: context.read<UserViewModel>().user?.name ?? 'User',
        user.id: user.name,
      },
      'profileImages': {
        currentUserId: context.read<UserViewModel>().user?.profileImage ?? '',
        user.id: user.profileImage,
      },
      'unreadCount.${user.id}': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  void _showEditDialog(String docId, String currentText, String chatRoomId) {
    final TextEditingController editController = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(
            controller: editController,
            decoration: const InputDecoration(hintText: "Enter new message"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newText = editController.text.trim();
                if (newText.isNotEmpty && newText != currentText) {
                  FirebaseFirestore.instance
                      .collection('chat_rooms')
                      .doc(chatRoomId)
                      .collection('messages')
                      .doc(docId)
                      .update({
                    'text': newText,
                    'isEdited': true,
                  });
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _markAsReadIfNeeded(List<QueryDocumentSnapshot> docs) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;
    final chatRoomId = getChatRoomId(currentUserId, widget.receiverId);

    bool needsUpdate = false;
    final batch = FirebaseFirestore.instance.batch();

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId']?.toString() ?? '';
      final status = data['status']?.toString() ?? '';

      if (senderId == widget.receiverId && status != 'read') {
        batch.update(doc.reference, {'status': 'read'});
        needsUpdate = true;
      }
    }

    if (needsUpdate) {
      batch.commit();
      FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).update({
        'unreadCount.$currentUserId': 0,
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void startAudioCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          username: widget.username,
          isVideoEnabled: false,
        ),
      ),
    );
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final amPm = date.hour >= 12 ? "PM" : "AM";
    return "$hour:${date.minute.toString().padLeft(2, '0')} $amPm";
  }

  void _onTyping(String value) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    final chatRoomId = getChatRoomId(currentUserId, widget.receiverId);
    FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).update({
      'typing_status.$currentUserId': true,
    }).catchError((_) {}); // Ignore if doc doesn't exist yet

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).update({
        'typing_status.$currentUserId': false,
      }).catchError((_) {});
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final chatRoomId = getChatRoomId(currentUserId, widget.receiverId);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios),
        ),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.receiverId).snapshots(),
          builder: (context, userSnapshot) {
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).snapshots(),
              builder: (context, chatSnapshot) {
                bool isTyping = false;
                if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                  final data = chatSnapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null && data['typing_status'] != null) {
                    isTyping = data['typing_status'][widget.receiverId] == true;
                  }
                }

                bool isOnline = false;
                String lastSeenText = '';
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final data = userSnapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null) {
                    isOnline = data['isOnline'] == true;
                    if (!isOnline && data['lastSeen'] != null) {
                      lastSeenText = "Last seen ${formatTimestamp(data['lastSeen'] as Timestamp)}";
                    }
                  }
                }

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(widget.profileImage),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.username,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isTyping ? "Typing..." : (isOnline ? "Online" : lastSeenText),
                          style: TextStyle(
                            color: isTyping || isOnline ? Colors.green : Colors.grey,
                            fontSize: 12,
                            fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoCallScreen(
                    username: widget.username,
                    isVideoEnabled: true,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: startAudioCall,
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(chatRoomId)
                  .collection('messages')
                  .orderBy('time', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _markAsReadIfNeeded(docs);
                    _scrollToBottom();
                  });
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
                    final timestamp = data['time'] as Timestamp?;
                    final isEdited = data['isEdited'] as bool? ?? false;
                    final isForwarded = data['isForwarded'] as bool? ?? false;
                    final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
                    final status = data['status']?.toString() ?? '';
                    final isMe = senderId == currentUserId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () => _showMessageOptions(doc.id, data),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: type == 'image'
                                      ? const EdgeInsets.all(4)
                                      : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  constraints: const BoxConstraints(maxWidth: 280),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.orange : Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      if (isForwarded)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.forward, size: 12, color: isMe ? Colors.white70 : Colors.grey),
                                              const SizedBox(width: 4),
                                              Text('Forwarded', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: isMe ? Colors.white70 : Colors.grey)),
                                            ],
                                          ),
                                        ),
                                      type == 'image'
                                          ? ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
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
                                if (reactions.isNotEmpty)
                                  Positioned(
                                    bottom: -8,
                                    right: isMe ? null : 10,
                                    left: isMe ? 10 : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                                          ]
                                      ),
                                      child: Text(
                                        reactions.values.toSet().join(''),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12, left: 6, right: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isEdited) ...[
                                    Text('Edited', style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontStyle: FontStyle.italic)),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    formatTimestamp(timestamp),
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      status == 'read' ? Icons.done_all : Icons.check,
                                      size: 14,
                                      color: status == 'read' ? Colors.blue : Colors.grey.shade500,
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ],
                        ),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.orange),
                  onPressed: () => _pickAndSendImage(ImageSource.gallery),
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.orange),
                  onPressed: () => _pickAndSendImage(ImageSource.camera),
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
                  onTap: () => sendMessage(),
                  child: Container(
                    height: 52,
                    width: 52,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
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
