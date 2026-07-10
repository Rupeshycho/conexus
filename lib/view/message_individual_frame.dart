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
import 'package:conexus/model/user_model.dart';
import 'package:conexus/services/cloudinary_service.dart';
import 'video_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String username;
  final String profileImage;

  static String? activeChatUserId;

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
  @override
  void initState() {
    super.initState();
    ChatScreen.activeChatUserId = widget.receiverId;
  }

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  Timer? _typingTimer;
  Map<String, dynamic>? _replyMessage;
  
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  String getChatRoomId(String uid1, String uid2) {
    final list = [uid1, uid2];
    list.sort();
    return "${list[0]}_${list[1]}";
  }

  void _scrollToMessage(String? messageId) {
    if (messageId == null || !_messageKeys.containsKey(messageId)) return;
    
    final context = _messageKeys[messageId]!.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      
      setState(() => _highlightedMessageId = messageId);
      Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightedMessageId = null);
      });
    }
  }

  void sendMessage({String? text, String? imageUrl, String type = 'text', bool isForwarded = false}) async {
    final msgText = text ?? messageController.text.trim();
    if (msgText.isEmpty && imageUrl == null && type != 'call') return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    final viewModel = context.read<UserViewModel>();
    final senderName = viewModel.user?.name ?? FirebaseAuth.instance.currentUser?.email ?? 'User';
    final senderImage = viewModel.user?.profileImage ?? 'https://i.pravatar.cc/150?u=$currentUserId';

    final chatRoomId = getChatRoomId(currentUserId, widget.receiverId);

    final replyData = _replyMessage;
    setState(() {
      _replyMessage = null;
    });

    if (type == 'text' && !isForwarded) {
      messageController.clear();
    }

    final now = FieldValue.serverTimestamp();

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
      'replyTo': replyData,
    });

    String lastMsgDisplay = msgText;
    if (type == 'image') lastMsgDisplay = '📷 Image';
    else if (type == 'video') lastMsgDisplay = '🎥 Video';
    else if (type == 'file') lastMsgDisplay = '📁 $msgText';
    else if (isForwarded) lastMsgDisplay = 'Forwarded: $msgText';

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId)
        .set({
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

    _scrollToBottom();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(image.path);
      final downloadUrl = await CloudinaryService.uploadImage(file);

      if (downloadUrl != null) {
        sendMessage(text: '', imageUrl: downloadUrl, type: 'image');
      } else {
        throw Exception("Upload failed");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickAndSendVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(video.path);
      final downloadUrl = await CloudinaryService.uploadVideo(file);

      if (downloadUrl != null) {
        sendMessage(text: '', imageUrl: downloadUrl, type: 'video');
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
        sendMessage(text: fileName, imageUrl: downloadUrl, type: 'file');
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final senderId = data['senderId']?.toString() ?? '';
    final isMe = currentUserId == senderId;
    final type = data['type']?.toString() ?? 'text';
    final chatRoomId = getChatRoomId(currentUserId, widget.receiverId);

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
                      'text': data['type'] == 'image'
                          ? '📷 Image'
                          : (data['type'] == 'video'
                              ? '🎥 Video'
                              : (data['type'] == 'file'
                                  ? '📁 ${data['text']}'
                                  : (data['text'] ?? ''))),
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
                    _showEditDialog(docId, data['text']?.toString() ?? '', chatRoomId);
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
        .set({'reactions': {currentUserId: emoji}}, SetOptions(merge: true));
  }

  void _showEditDialog(String docId, String currentText, String chatRoomId) {
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;
    final chatRoomId = getChatRoomId(currentUserId, widget.receiverId);
    bool needsUpdate = false;
    final batch = FirebaseFirestore.instance.batch();

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['senderId'] == widget.receiverId && data['status'] != 'read') {
        batch.update(doc.reference, {'status': 'read'});
        needsUpdate = true;
      }
    }

    if (needsUpdate) {
      batch.commit();
      FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).update({'unreadCount.$currentUserId': 0});
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    return "$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? "PM" : "AM"}";
  }

  void _onTyping(String value) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final chatRoomId = getChatRoomId(currentUserId, widget.receiverId);
    FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).update({'typing_status.$currentUserId': true});
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).update({'typing_status.$currentUserId': false});
    });
  }

  @override
  void dispose() {
    if (ChatScreen.activeChatUserId == widget.receiverId) {
      ChatScreen.activeChatUserId = null;
    }
    _typingTimer?.cancel();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _initiateCall(BuildContext context, {required bool isVideo}) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    final viewModel = context.read<UserViewModel>();
    final senderName = viewModel.user?.name ?? FirebaseAuth.instance.currentUser?.email ?? 'User';
    final senderImage = viewModel.user?.profileImage ?? 'https://i.pravatar.cc/150?u=$currentUserId';

    final callDoc = FirebaseFirestore.instance.collection('calls').doc();
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
      Navigator.push(
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
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final chatRoomId = getChatRoomId(currentUserId, widget.receiverId);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios)),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.receiverId).snapshots(),
          builder: (context, userSnapshot) {
            bool isOnline = userSnapshot.hasData && (userSnapshot.data?.data() as Map?)?['isOnline'] == true;
            return Row(
              children: [
                CircleAvatar(radius: 20, backgroundImage: NetworkImage(widget.profileImage)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.username, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(isOnline ? "Online" : "Offline", style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.orange),
            onPressed: () => _initiateCall(context, isVideo: false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.orange),
            onPressed: () => _initiateCall(context, isVideo: true),
          ),
          const SizedBox(width: 8),
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
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                WidgetsBinding.instance.addPostFrameCallback((_) => _markAsReadIfNeeded(docs));

                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == currentUserId;
                    final replyTo = data['replyTo'] as Map<String, dynamic>?;
                    final reactions = data['reactions'] as Map<String, dynamic>?;
                    
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
                              padding: (data['type'] == 'image' || data['type'] == 'video')
                                  ? const EdgeInsets.all(4)
                                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _highlightedMessageId == doc.id 
                                    ? Colors.orange.withOpacity(0.3)
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
                                          color: Colors.black.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(replyTo['senderName'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                                            Text(replyTo['text'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (data['type'] == 'image')
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
                                              color: Colors.white.withOpacity(0.2),
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
                                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, spreadRadius: 1)
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
                  Expanded(child: Text("Replying to ${_replyMessage!['senderName']}\n${_replyMessage!['text']}", maxLines: 2, overflow: TextOverflow.ellipsis)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _replyMessage = null)),
                ],
              ),
            ),
            
          if (_isUploading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.withOpacity(0.1),
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
                IconButton(icon: const Icon(Icons.send, color: Colors.orange), onPressed: () => sendMessage()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
