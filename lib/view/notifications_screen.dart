// lib/view/notifications_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conexus/view/other_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final userUid = _auth.currentUser?.uid ?? 'test_user_123';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F4),
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            onPressed: () {
              _markAllAsRead(userUid);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(userUid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.deepOrange,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}"),
            );
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No Notifications Yet",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "When someone follows you, you'll see it here",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;
              final notifId = notifications[index].id;

              return _buildNotificationCard(
                data: data,
                notifId: notifId,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _markAllAsRead(String? userUid) async {
    if (userUid == null) return;

    try {
      final notifications = await _firestore
          .collection('users')
          .doc(userUid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        await doc.reference.update({'isRead': true});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All notifications marked as read"),
            backgroundColor: Colors.deepOrange,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error marking all as read: $e");
    }
  }

  Widget _buildNotificationCard({
    required Map<String, dynamic> data,
    required String notifId,
  }) {
    final String type = data['type'] ?? '';
    final String message = data['message'] ?? '';
    final String fromUid = data['fromUid'] ?? '';
    final bool isRead = data['isRead'] ?? false;
    final DateTime? createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return GestureDetector(
      onTap: () {
        if (fromUid.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtherProfileScreen(userId: fromUid),
            ),
          );
          _markAsRead(notifId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? Colors.grey.shade200 : Colors.deepOrange.shade100,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.deepOrange.shade100,
              child: Icon(
                _getNotificationIcon(type),
                color: Colors.deepOrange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                      color: isRead ? Colors.grey.shade700 : Colors.black87,
                    ),
                  ),
                  if (createdAt != null)
                    Text(
                      _timeAgo(createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.deepOrange,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsRead(String notifId) async {
    try {
      final userUid = _auth.currentUser?.uid;
      if (userUid == null) return;

      await _firestore
          .collection('users')
          .doc(userUid)
          .collection('notifications')
          .doc(notifId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'follow':
        return Icons.person_add;
      case 'unfollow':
        return Icons.person_remove;
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      default:
        return Icons.notifications;
    }
  }

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}