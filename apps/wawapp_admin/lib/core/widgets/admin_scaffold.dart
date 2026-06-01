import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/animations.dart';
import '../theme/colors.dart';
import '../utils/responsive_helper.dart';
import 'admin_sidebar.dart';
import 'notifications_dropdown.dart';
import '../../features/notifications/providers/admin_notifications_provider.dart';
import '../../providers/theme_provider.dart';

class AdminScaffold extends ConsumerStatefulWidget {
  final Widget? child;
  final Widget? body;
  final String title;
  final List<Widget>? actions;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;

  const AdminScaffold({
    super.key,
    this.child,
    this.body,
    required this.title,
    this.actions,
    this.searchController,
    this.onSearchChanged,
  }) : assert(child != null || body != null, 'Either child or body must be provided');

  @override
  ConsumerState<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends ConsumerState<AdminScaffold> with SingleTickerProviderStateMixin {
  bool _isSidebarCollapsed = false;
  late TextEditingController _searchController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _searchController = widget.searchController ?? TextEditingController();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    if (widget.searchController == null) {
      _searchController.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged() {
    widget.onSearchChanged?.call(_searchController.text);
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _openMobileDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.shouldShowMobileLayout(context);
    final appBarHeight = ResponsiveHelper.getAppBarHeight(context);

    // Watch notifications from Firestore
    final notificationsAsync = ref.watch(adminNotificationsStreamProvider);
    final notifications = notificationsAsync.valueOrNull ?? [];
    final service = ref.read(adminNotificationsServiceProvider);

    // Explicit Directionality to ensure RTL works on all browsers
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        // Mobile drawer
        drawer: isMobile ? _buildMobileDrawer() : null,
        body: Material(
          child: Row(
            children: [
              // Desktop sidebar (hidden on mobile)
              if (!isMobile)
                AnimatedContainer(
                  duration: AdminAnimations.normal,
                  curve: AdminAnimations.defaultCurve,
                  width: _isSidebarCollapsed ? AdminSpacing.sidebarWidthCollapsed : AdminSpacing.sidebarWidth,
                  child: AdminSidebar(isCollapsed: _isSidebarCollapsed, onToggle: _toggleSidebar),
                ),

              // Main content area
              Expanded(
                child: Column(
                  children: [
                    // Top app bar
                    AnimatedContainer(
                      duration: AdminAnimations.fast,
                      height: appBarHeight,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: const Border(bottom: BorderSide(color: AdminAppColors.borderLight)),
                        boxShadow: const [
                          BoxShadow(color: AdminAppColors.shadowLight, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? AdminSpacing.md : AdminSpacing.lg),
                        child: Row(
                          children: [
                            // Hamburger menu on mobile
                            if (isMobile)
                              HoverAnimatedContainer(
                                onTap: _openMobileDrawer,
                                child: IconButton(
                                  icon: const Icon(Icons.menu),
                                  onPressed: _openMobileDrawer,
                                  tooltip: 'القائمة',
                                ),
                              ),

                            // Title
                            Expanded(
                              child: Text(
                                widget.title,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 18, desktop: 24),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            const SizedBox(width: AdminSpacing.md),

                            // Search bar
                            AnimatedContainer(
                              duration: AdminAnimations.fast,
                              width: ResponsiveHelper.responsiveWidth(context, mobile: 150, tablet: 250, desktop: 300),
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'بحث...',
                                  prefixIcon: const Icon(Icons.search, size: 20),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AdminSpacing.radiusFull),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: AdminAppColors.backgroundLight,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? AdminSpacing.sm : AdminSpacing.md,
                                    vertical: AdminSpacing.sm,
                                  ),
                                  isDense: true,
                                ),
                                style: TextStyle(fontSize: isMobile ? 12 : 14),
                              ),
                            ),

                            const SizedBox(width: AdminSpacing.sm),

                            // Notifications dropdown — live from Firestore
                            NotificationsDropdown(
                              notifications: notifications,
                              onViewAll: () => context.go('/notifications'),
                              onNotificationTap: (id) {
                                // Find notification and navigate to its route
                                final notification = notifications.where((n) => n.id == id).firstOrNull;
                                if (notification != null) {
                                  service.markAsRead(id);
                                  if (notification.actionRoute != null) {
                                    context.go(notification.actionRoute!);
                                  }
                                }
                              },
                              onMarkAsRead: (id) => service.markAsRead(id),
                            ),

                            // Theme toggle (hide on very small mobile)
                            if (!isMobile || MediaQuery.of(context).size.width > 400)
                              HoverAnimatedContainer(
                                child: IconButton(
                                  icon: Icon(
                                    ref.watch(themeModeProvider) == ThemeMode.dark
                                        ? Icons.light_mode_outlined
                                        : Icons.dark_mode_outlined,
                                  ),
                                  onPressed: () {
                                    ref.read(themeModeProvider.notifier).toggle();
                                  },
                                  tooltip: 'تبديل السمة',
                                ),
                              ),

                            // Custom actions
                            if (widget.actions != null) ...widget.actions!,
                          ],
                        ),
                      ),
                    ),

                    // Content area with scroll
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: AdminAnimations.normal,
                        child: SingleChildScrollView(
                          key: ValueKey(widget.title),
                          padding: ResponsiveHelper.responsivePadding(context),
                          child: widget.child ?? widget.body!,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: AdminSidebar(
        isCollapsed: false,
        onToggle: () {
          Navigator.of(context).pop(); // Close drawer when toggling
        },
      ),
    );
  }
}
