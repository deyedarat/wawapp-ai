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
    if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} د';
    if (difference.inHours < 24) return 'منذ ${difference.inHours} س';
    if (difference.inDays < 7) return 'منذ ${difference.inDays} يوم';
    return 'منذ ${(difference.inDays / 7).floor()} أسبوع';
  }
}

/// Professional Notifications Dropdown
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

class _NotificationsDropdownState extends State<NotificationsDropdown>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  OverlayEntry? _overlayEntry;
  final _buttonKey = GlobalKey();
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounceAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(NotificationsDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUnread = oldWidget.notifications.where((n) => !n.isRead).length;
    final newUnread = widget.notifications.where((n) => !n.isRead).length;
    if (newUnread > oldUnread) {
      _bounceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    final unreadCount = widget.notifications.where((n) => !n.isRead).length;
    setState(() => _isOpen = true);

    _overlayEntry = OverlayEntry(
      builder: (context) => _NotificationsOverlay(
        buttonKey: _buttonKey,
        notifications: widget.notifications,
        unreadCount: unreadCount,
        onClose: _closeDropdown,
        onViewAll: () {
          _closeDropdown();
          widget.onViewAll?.call();
        },
        onNotificationTap: (id) {
          _closeDropdown();
          widget.onNotificationTap?.call(id);
        },
        onMarkAsRead: widget.onMarkAsRead,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = widget.notifications.where((n) => !n.isRead).length;

    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_bounceAnimation.value * 0.05),
          child: child,
        );
      },
      child: Tooltip(
        message: 'الإشعارات',
        child: InkWell(
          key: _buttonKey,
          onTap: _toggleDropdown,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isOpen
                  ? AdminAppColors.primaryGreen.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  _isOpen
                      ? Icons.notifications_rounded
                      : Icons.notifications_outlined,
                  size: 24,
                  color: _isOpen
                      ? AdminAppColors.primaryGreen
                      : AdminAppColors.textSecondaryLight,
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: unreadCount > 9 ? Colors.orange : Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Overlay Panel ─────────────────────────────────────────────────────────────

class _NotificationsOverlay extends StatefulWidget {
  final GlobalKey buttonKey;
  final List<AdminNotification> notifications;
  final int unreadCount;
  final VoidCallback onClose;
  final VoidCallback? onViewAll;
  final Function(String)? onNotificationTap;
  final Function(String)? onMarkAsRead;

  const _NotificationsOverlay({
    required this.buttonKey,
    required this.notifications,
    required this.unreadCount,
    required this.onClose,
    this.onViewAll,
    this.onNotificationTap,
    this.onMarkAsRead,
  });

  @override
  State<_NotificationsOverlay> createState() => _NotificationsOverlayState();
}

class _NotificationsOverlayState extends State<_NotificationsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate position relative to button
    final RenderBox? buttonBox =
        widget.buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final buttonOffset = buttonBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final buttonSize = buttonBox?.size ?? Size.zero;
    final screenWidth = MediaQuery.of(context).size.width;
    const panelWidth = 380.0;

    double left = buttonOffset.dx - panelWidth + buttonSize.width + 8;
    if (left < 8) left = 8;
    if (left + panelWidth > screenWidth - 8)
      left = screenWidth - panelWidth - 8;
    final top = buttonOffset.dy + buttonSize.height + 8;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onClose,
      child: Stack(
        children: [
          // Scrim
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Panel
          Positioned(
            left: left,
            top: top,
            width: panelWidth,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: GestureDetector(
                  onTap: () {}, // prevent scrim close
                  child: Material(
                    elevation: 12,
                    shadowColor: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.65,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHeader(),
                            if (widget.notifications.isEmpty)
                              _buildEmptyBody()
                            else
                              Flexible(child: _buildNotificationsList()),
                            if (widget.notifications.isNotEmpty) _buildFooter(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminAppColors.borderLight)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_rounded,
              color: AdminAppColors.primaryGreen, size: 20),
          const SizedBox(width: 8),
          const Text(
            'الإشعارات',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const Spacer(),
          if (widget.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AdminAppColors.primaryGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.unreadCount} جديد',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          InkWell(
            onTap: widget.onClose,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close,
                  size: 18, color: AdminAppColors.textSecondaryLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    final display = widget.notifications.take(7).toList();
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: display.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AdminAppColors.borderLight),
      itemBuilder: (context, i) => _buildNotificationItem(display[i]),
    );
  }

  Widget _buildNotificationItem(AdminNotification n) {
    return InkWell(
      onTap: () => widget.onNotificationTap?.call(n.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: n.isRead ? null : n.color.withOpacity(0.03),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color bar for unread
            if (!n.isRead)
              Container(
                width: 3,
                height: 42,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: n.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: n.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(n.icon, color: n.color, size: 18),
            ),
            const SizedBox(width: 10),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          n.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AdminAppColors.textSecondaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.timeAgo,
                    style: TextStyle(
                      fontSize: 10,
                      color: AdminAppColors.textSecondaryLight.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            // Mark as read button
            if (!n.isRead)
              Tooltip(
                message: 'تحديد كمقروء',
                child: InkWell(
                  onTap: () {
                    widget.onMarkAsRead?.call(n.id);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AdminAppColors.primaryGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: AdminAppColors.primaryGreen,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AdminAppColors.borderLight)),
      ),
      child: TextButton(
        onPressed: widget.onViewAll,
        style: TextButton.styleFrom(
          foregroundColor: AdminAppColors.primaryGreen,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: const RoundedRectangleBorder(),
          minimumSize: const Size(double.infinity, 0),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'عرض جميع الإشعارات',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 11),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyBody() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 44,
            color: AdminAppColors.textSecondaryLight.withOpacity(0.4),
          ),
          const SizedBox(height: 10),
          Text(
            'لا توجد إشعارات جديدة',
            style: TextStyle(
              color: AdminAppColors.textSecondaryLight.withOpacity(0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
