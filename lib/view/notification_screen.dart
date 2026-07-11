// lib/view/notification_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../services/firebase_service.dart';
import '../viewmodel/notification_viewmodel.dart';

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
      appBar: AppBar(title: const Text('Notifications')),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : viewModel.notifications.isEmpty
          ? const Center(child: Text('No notifications yet'))
          : ListView.builder(
              itemCount: viewModel.notifications.length,
              itemBuilder: (context, index) {
                final n = viewModel.notifications[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: n.fromUserPhotoUrl.isNotEmpty
                        ? NetworkImage(n.fromUserPhotoUrl)
                        : null,
                    child: n.fromUserPhotoUrl.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(n.message),
                  subtitle: Text(timeago.format(n.createdAt)),
                  tileColor: n.isRead ? null : Colors.orange.withOpacity(0.08),
                  onTap: () {
                    context.read<NotificationViewModel>().markAsRead(
                      n.notificationId,
                    );
                  },
                );
              },
            ),
    );
  }
}
