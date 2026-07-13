// lib/view/blocked_users_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conexus/model/user_model.dart';
import 'package:conexus/viewmodel/user_view_model.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  static const Color orange = Color(0xFFB5651D);

  Future<void> _confirmUnblock(BuildContext context, UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unblock user?'),
        content: Text(
          '${user.name} will be able to see your profile and follow you again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unblock', style: TextStyle(color: orange)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await context.read<UserViewModel>().unblock(user.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} unblocked')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unblock: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Live: rebuilds whenever UserViewModel notifies (e.g. after block/unblock).
    final userViewModel = context.watch<UserViewModel>();
    final blockedIds = userViewModel.user?.blockedUsers ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: blockedIds.isEmpty
          ? Center(
        child: Text(
          "You haven't blocked anyone",
          style: TextStyle(color: Colors.grey[600]),
        ),
      )
          : FutureBuilder<List<UserModel>>(
        // Re-runs whenever this widget rebuilds with a new
        // blockedIds list (i.e. right after block()/unblock()).
        future: Future.wait(
          blockedIds.map((id) => userViewModel.getUser(id)),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load blocked users: ${snapshot.error}'),
            );
          }

          final profiles = snapshot.data ?? [];

          if (profiles.isEmpty) {
            return Center(
              child: Text(
                "You haven't blocked anyone",
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: profiles.length,
            separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 72, endIndent: 16),
            itemBuilder: (context, index) {
              final user = profiles[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: user.profileImage.isNotEmpty
                      ? NetworkImage(user.profileImage)
                      : null,
                  child: user.profileImage.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(
                  user.name.isEmpty ? 'Unknown user' : user.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: user.username.isNotEmpty
                    ? Text('@${user.username}')
                    : null,
                trailing: OutlinedButton(
                  onPressed: () => _confirmUnblock(context, user),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: orange,
                    side: const BorderSide(color: orange),
                  ),
                  child: const Text('Unblock'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}