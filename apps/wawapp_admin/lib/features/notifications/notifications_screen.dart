import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/notifications_dropdown.dart';
import 'providers/admin_notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(adminNotificationsStreamProvider);
    final service = ref.read(adminNotificationsServiceProvider);

    return AdminScaffold(
      title: 'الإشعارات',
      actions: [
        TextButton.icon(
          onPressed: () async {
            await service.markAllAsRead();
          },
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('تحديد الكل كمقروء'),
        ),
      ],
      child: notificationsAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'حدث خطأ في تحميل الإشعارات',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildNotificationsList(context, notifications, service, ref);
        },
      ),
    );
  }

  Widget _buildNotificationsList(
    BuildContext context,
    List<AdminNotification> notifications,
    AdminNotificationsService service,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary row
        Padding(
          padding: const EdgeInsets.only(bottom: AdminSpacing.md),
          child: Text(
            '${notifications.where((n) => !n.isRead).length} إشعار غير مقروء من أصل ${notifications.length}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AdminAppColors.textSecondaryLight,
                ),
          ),
        ),

        // Notifications list
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: notifications.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AdminAppColors.borderLight),
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _buildNotificationTile(
              context,
              notification,
              service,
              ref,
            );
          },
        ),
      ],
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    AdminNotification notification,
    AdminNotificationsService service,
    WidgetRef ref,
  ) {
    return InkWell(
      onTap: () async {
        // Mark as read
        if (!notification.isRead) {
          await service.markAsRead(notification.id);
        }
        // Navigate to related page
        if (notification.actionRoute != null && context.mounted) {
          context.go(notification.actionRoute!);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(AdminSpacing.md),
        color: notification.isRead
            ? Colors.transparent
            : AdminAppColors.primaryGreen.withValues(alpha: 0.04),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(AdminSpacing.sm),
              decoration: BoxDecoration(
                color: notification.color.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AdminSpacing.radiusSm),
              ),
              child: Icon(
                notification.icon,
                color: notification.color,
                size: 22,
              ),
            ),
            const SizedBox(width: AdminSpacing.md),

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
                            fontWeight: notification.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                            fontSize: 14,
                          ),
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
                      fontSize: 13,
                      color: AdminAppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: AdminSpacing.xxs),
                  Text(
                    notification.timeAgo,
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          AdminAppColors.textSecondaryLight.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Mark as read button (only for unread)
            if (!notification.isRead)
              IconButton(
                icon: const Icon(Icons.check, size: 18),
                tooltip: 'تحديد كمقروء',
                color: AdminAppColors.primaryGreen,
                onPressed: () => service.markAsRead(notification.id),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: AdminAppColors.textSecondaryLight.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد إشعارات',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AdminAppColors.textSecondaryLight,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
