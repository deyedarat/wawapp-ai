import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/notifications_dropdown.dart';
import 'providers/admin_notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isMarkingAll = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(adminNotificationsStreamProvider);
    final service = ref.read(adminNotificationsServiceProvider);

    return AdminScaffold(
      title: 'الإشعارات',
      actions: [
        // Mark all as read button
        notificationsAsync.maybeWhen(
          data: (notifications) {
            final hasUnread = notifications.any((n) => !n.isRead);
            if (!hasUnread) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: _isMarkingAll
                  ? null
                  : () async {
                      setState(() => _isMarkingAll = true);
                      await service.markAllAsRead();
                      if (mounted) setState(() => _isMarkingAll = false);
                    },
              icon: _isMarkingAll
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.done_all, size: 18),
              label: const Text('تحديد الكل مقروء'),
              style: TextButton.styleFrom(
                foregroundColor: AdminAppColors.primaryGreen,
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
      child: notificationsAsync.when(
        loading: () => const _LoadingState(),
        error: (error, _) => _ErrorState(error: error.toString()),
        data: (notifications) {
          if (notifications.isEmpty) return const _EmptyState();

          final unread = notifications.where((n) => !n.isRead).toList();
          final read = notifications.where((n) => n.isRead).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Stats row ───────────────────────────────────────────────
              _buildStatsRow(notifications, unread),
              const SizedBox(height: 20),

              // ── Tab Bar ─────────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AdminAppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AdminAppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AdminAppColors.textSecondaryLight,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('غير مقروءة'),
                          if (unread.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${unread.length}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('المقروءة'),
                          if (read.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${read.length}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Tab content ──────────────────────────────────────────────
              SizedBox(
                height: unread.isEmpty && read.isEmpty ? 200 : null,
                child: [
                  // Unread tab
                  unread.isEmpty
                      ? const _EmptyTabState(message: 'لا توجد إشعارات غير مقروءة')
                      : _NotificationsList(
                          notifications: unread,
                          service: service,
                          showMarkAsRead: true,
                        ),
                  // Read tab
                  read.isEmpty
                      ? const _EmptyTabState(message: 'لا توجد إشعارات مقروءة')
                      : _NotificationsList(
                          notifications: read,
                          service: service,
                          showMarkAsRead: false,
                        ),
                ][_tabController.index],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(
    List<AdminNotification> all,
    List<AdminNotification> unread,
  ) {
    final typeGroups = <String, int>{};
    for (final n in all) {
      final type = n.icon == Icons.local_shipping
          ? 'طلب'
          : n.icon == Icons.person_add
              ? 'سائق'
              : n.icon == Icons.account_balance_wallet || n.icon == Icons.payments
                  ? 'مالية'
                  : 'أخرى';
      typeGroups[type] = (typeGroups[type] ?? 0) + 1;
    }

    return Row(
      children: [
        _StatCard(
          label: 'الكل',
          value: all.length,
          color: AdminAppColors.primaryGreen,
          icon: Icons.notifications,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'غير مقروء',
          value: unread.length,
          color: Colors.orange,
          icon: Icons.mark_email_unread,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'مقروء',
          value: all.length - unread.length,
          color: Colors.blue,
          icon: Icons.mark_email_read,
        ),
      ],
    );
  }
}

// ── Notification list ─────────────────────────────────────────────────────────

class _NotificationsList extends StatelessWidget {
  final List<AdminNotification> notifications;
  final AdminNotificationsService service;
  final bool showMarkAsRead;

  const _NotificationsList({
    required this.notifications,
    required this.service,
    required this.showMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _NotificationCard(
          notification: notifications[index],
          service: service,
          showMarkAsRead: showMarkAsRead,
        );
      },
    );
  }
}

// ── Single notification card ──────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final AdminNotification notification;
  final AdminNotificationsService service;
  final bool showMarkAsRead;

  const _NotificationCard({
    required this.notification,
    required this.service,
    required this.showMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (!notification.isRead) {
            await service.markAsRead(notification.id);
          }
          if (notification.actionRoute != null && context.mounted) {
            context.go(notification.actionRoute!);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Theme.of(context).colorScheme.surface
                : notification.color.withOpacity(0.04),
            border: Border.all(
              color: notification.isRead
                  ? AdminAppColors.borderLight
                  : notification.color.withOpacity(0.25),
              width: notification.isRead ? 1 : 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: notification.isRead
                ? []
                : [
                    BoxShadow(
                      color: notification.color.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: notification.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(notification.icon, color: notification.color, size: 24),
              ),
              const SizedBox(width: 14),

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
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              fontSize: 14,
                              color: notification.isRead
                                  ? AdminAppColors.textSecondaryLight
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        // Unread dot
                        if (!notification.isRead)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(left: 6, right: 6),
                            decoration: BoxDecoration(
                              color: notification.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: notification.isRead
                            ? AdminAppColors.textSecondaryLight.withOpacity(0.8)
                            : AdminAppColors.textSecondaryLight,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: AdminAppColors.textSecondaryLight.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(notification.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: AdminAppColors.textSecondaryLight.withOpacity(0.7),
                          ),
                        ),
                        const Spacer(),
                        // Type badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: notification.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            notification.timeAgo,
                            style: TextStyle(
                              fontSize: 10,
                              color: notification.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              if (showMarkAsRead) ...[
                const SizedBox(width: 8),
                Column(
                  children: [
                    Tooltip(
                      message: 'تحديد كمقروء',
                      child: InkWell(
                        onTap: () => service.markAsRead(notification.id),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AdminAppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 16,
                            color: AdminAppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(dt);
    } else if (diff.inDays < 7) {
      return DateFormat('EEE HH:mm', 'ar').format(dt);
    } else {
      return DateFormat('dd/MM/yyyy', 'ar').format(dt);
    }
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          border: Border.all(color: color.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AdminAppColors.backgroundLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: AdminAppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد إشعارات',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AdminAppColors.textSecondaryLight,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'ستظهر هنا إشعارات الطلبات الجديدة والسائقين والمدفوعات',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AdminAppColors.textSecondaryLight,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTabState extends StatelessWidget {
  final String message;
  const _EmptyTabState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 40,
            color: AdminAppColors.textSecondaryLight.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: AdminAppColors.textSecondaryLight.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جار تحميل الإشعارات...'),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
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
              error,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
