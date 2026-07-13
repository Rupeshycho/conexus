// lib/view/notification_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:conexus/model/notification_model.dart';
import '../services/firebase_service.dart';
import '../viewmodel/notification_viewmodel.dart';
import 'other_profile_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseService.currentUserId ?? '';
      context.read<NotificationViewModel>().listenToNotifications(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<NotificationViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F4),
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            onPressed: () => _markAllAsRead(context, viewModel),
          ),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.deepOrange),
      )
          : viewModel.notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: viewModel.notifications.length,
        itemBuilder: (context, index) {
          final n = viewModel.notifications[index];
          return _buildNotificationCard(context, n, viewModel);
        },
      ),
    );
  }

  Future<void> _markAllAsRead(
      BuildContext context,
      NotificationViewModel viewModel,
      ) async {
    await viewModel.markAllAsRead();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: Colors.deepOrange,
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Notifications Yet',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            "When someone follows you, you'll see it here",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
      BuildContext context,
      NotificationModel n,
      NotificationViewModel viewModel,
      ) {
    return GestureDetector(
      onTap: () {
        if (n.fromUserId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtherProfileScreen(userId: n.fromUserId),
            ),
          );
        }
        if (!n.isRead) {
          viewModel.markAsRead(n.notificationId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: n.isRead ? Colors.white : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: n.isRead ? Colors.grey.shade200 : Colors.deepOrange.shade100,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.deepOrange.shade100,
              backgroundImage: n.fromUserPhotoUrl.isNotEmpty
                  ? NetworkImage(n.fromUserPhotoUrl)
                  : null,
              child: n.fromUserPhotoUrl.isEmpty
                  ? Icon(_getNotificationIcon(n.type), color: Colors.deepOrange, size: 24)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.message,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600,
                      color: n.isRead ? Colors.grey.shade700 : Colors.black87,
                    ),
                  ),
                  Text(
                    timeago.format(n.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            if (!n.isRead)
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

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.follow:
        return Icons.person_add;
      case NotificationType.like:
        return Icons.favorite;
      case NotificationType.comment:
        return Icons.comment;
    }
  }
}
