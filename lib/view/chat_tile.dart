import 'package:flutter/material.dart';

class ChatTile extends StatelessWidget {
  final String username;
  final String profileImage;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isOnline;
  final VoidCallback onTap;

  const ChatTile({
    super.key,
    required this.username,
    required this.profileImage,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isOnline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark ? Colors.grey[900]! : Colors.white;
    final secondaryTextColor = isDark ? Colors.grey[400]! : Colors.grey.shade600;
    final tertiaryTextColor = isDark ? Colors.grey[500]! : Colors.grey.shade500;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // PROFILE IMAGE
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    backgroundImage: NetworkImage(profileImage),
                    onBackgroundImageError: (_, __) {},
                    child: profileImage.isEmpty
                        ? Icon(Icons.person, color: isDark ? Colors.grey[500] : Colors.grey[400])
                        : null,
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        height: 14,
                        width: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: cardColor, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // USER INFO
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: secondaryTextColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // TIME + UNREAD
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(fontSize: 12, color: tertiaryTextColor),
                  ),
                  const SizedBox(height: 8),
                  if (unreadCount > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}