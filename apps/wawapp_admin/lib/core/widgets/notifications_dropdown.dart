import 'package:flutter/material.dart';

import '../theme/animations.dart';
import '../theme/colors.dart';

/// Notification model for admin panel
class AdminNotification {
  final String id;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final DateTime timestamp;
  final bool isRead;
  final String? actionRoute;

  const AdminNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.timestamp,
    this.isRead = false,
    this.actionRoute,
  });

  String get timeAgo {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) return 'الآن';
    if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} دقيقة';
    if (difference.inHours < 24) return 'منذ ${difference.inHours} ساعة';
    if (difference.inDays < 7) return 'منذ ${difference.inDays} يوم';
    return 'منذ ${(difference.inDays / 7).floor()} أسبوع';
  }
}

/// Notifications dropdown widget
class NotificationsDropdown extends StatefulWidget {
  final List<AdminNotification> notifications;
  final VoidCallback? onViewAll;
  final Function(String)? onNotificationTap;
  final Function(String)? onMarkAsRead;

  const NotificationsDropdown({
    super.key,
    required this.notifications,
    this.onViewAll,
    this.onNotificationTap,
    this.onMarkAsRead,
  });

  @override
  State<NotificationsDropdown> createState() => _NotificationsDropdownState();
}

class _NotificationsDropdownState extends State<NotificationsDropdown> {
  @override
  Widget build(BuildContext context) {
    final unreadCount = widget.notifications.where((n) => !n.isRead).length;

    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
      ),
      icon: HoverAnimatedContainer(
        child: Badge(
          label: Text('$unreadCount'),
          isLabelVisible: unreadCount > 0,
          child: const Icon(Icons.notifications_outlined),
        ),
      ),
      tooltip: 'الإشعارات',
      itemBuilder: (context) {
        if (widget.notifications.isEmpty) {
          return [
            PopupMenuItem<String>(
              enabled: false,
              child: _buildEmptyState(),
            ),
          ];
        }

        final items = <PopupMenuEntry<String>>[];

        // Header
        items.add(
          PopupMenuItem<String>(
            enabled: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AdminSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الإشعارات',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AdminSpacing.sm,
                        vertical: AdminSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: AdminAppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(AdminSpacing.radiusFull),
                      ),
                      child: Text(
                        '$unreadCount جديد',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

        items.add(const PopupMenuDivider());

        // Notification items (show max 5)
        final displayNotifications = widget.notifications.take(5).toList();
        for (var notification in displayNotifications) {
          items.add(
            PopupMenuItem<String>(
              value: notification.id,
              padding: EdgeInsets.zero,
              child: _buildNotificationItem(notification),
            ),
          );
        }

        // View all button
        if (widget.notifications.length > 5 || widget.onViewAll != null) {
          items.add(const PopupMenuDivider());
          items.add(
            const PopupMenuItem<String>(
              value: 'view_all',
              child: Center(
                child: Text(
                  'عرض جميع الإشعارات',
                  style: TextStyle(
                    color: AdminAppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }

        return items;
      },
      onSelected: (value) {
        if (value == 'view_all') {
          widget.onViewAll?.call();
        } else {
          widget.onNotificationTap?.call(value);
        }
      },
    );
  }

  Widget _buildNotificationItem(AdminNotification notification) {
    return HoverAnimatedContainer(
      hoverScale: 1.0,
      child: Container(
        padding: const EdgeInsets.all(AdminSpacing.md),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.transparent : AdminAppColors.primaryGreen.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(AdminSpacing.sm),
              decoration: BoxDecoration(
                color: notification.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
              ),
              child: Icon(
                notification.icon,
                color: notification.color,
                size: 20,
              ),
            ),
            const SizedBox(width: AdminSpacing.sm),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AdminAppColors.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AdminSpacing.xxs),
                  Text(
                    notification.message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AdminAppColors.textSecondaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AdminSpacing.xxs),
                  Text(
                    notification.timeAgo,
                    style: TextStyle(
                      fontSize: 11,
                      color: AdminAppColors.textSecondaryLight.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none,
            size: 48,
            color: AdminAppColors.textSecondaryLight.withOpacity(0.5),
          ),
          const SizedBox(height: AdminSpacing.sm),
          const Text(
            'لا توجد إشعارات',
            style: TextStyle(
              color: AdminAppColors.textSecondaryLight,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
