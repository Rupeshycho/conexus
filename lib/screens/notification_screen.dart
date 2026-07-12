import 'package:flutter/material.dart';

import '../model/notification_model.dart';
import '../repo/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final String currentUserId = 'user123'; // Replace with actual user ID

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<NotificationModel>>(
        stream: NotificationService.getNotifications(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(notif.senderId[0].toUpperCase()),
                ),
                title: Text(notif.message),
                subtitle: Text(
                  notif.timestamp.toLocal().toString().split('.')[0],
                ),
                trailing: notif.isRead
                    ? const Icon(Icons.check_circle, color: Colors.grey)
                    : const Icon(Icons.circle, color: Colors.blue, size: 12),
                onTap: () async {
                  await NotificationService.markRead(notif.id);
                  setState(() {});
                },
                onLongPress: () async {
                  await NotificationService.deleteNotification(notif.id);
                  setState(() {});
                },
              );
            },
          );
        },
      ),
    );
  }
}
