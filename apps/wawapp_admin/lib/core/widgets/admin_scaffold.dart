import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'admin_sidebar.dart';

class AdminScaffold extends StatefulWidget {
  final Widget child;
  final String title;
  final List<Widget>? actions;

  const AdminScaffold({
    super.key,
    required this.child,
    required this.title,
    this.actions,
  });

  @override
  State<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends State<AdminScaffold> {
  bool _isSidebarCollapsed = false;

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AdminSidebar(
            isCollapsed: _isSidebarCollapsed,
            onToggle: _toggleSidebar,
          ),

          // Main content area
          Expanded(
            child: Column(
              children: [
                // Top app bar
                Container(
                  height: AdminSpacing.appBarHeight,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: const Border(
                      bottom: BorderSide(color: AdminAppColors.borderLight),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: AdminSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        // Title
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const Spacer(),

                        // Search bar
                        SizedBox(
                          width: 300,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'بحث...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AdminSpacing.radiusFull,
                                ),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: AdminAppColors.backgroundLight,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: AdminSpacing.md,
                                vertical: AdminSpacing.sm,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),

                        SizedBox(width: AdminSpacing.md),

                        // Notifications icon
                        IconButton(
                          icon: const Badge(
                            label: Text('3'),
                            child: Icon(Icons.notifications_outlined),
                          ),
                          onPressed: () {
                            // TODO: Show notifications
                          },
                          tooltip: 'الإشعارات',
                        ),

                        SizedBox(width: AdminSpacing.xs),

                        // Theme toggle
                        IconButton(
                          icon: const Icon(Icons.brightness_6_outlined),
                          onPressed: () {
                            // TODO: Toggle theme
                          },
                          tooltip: 'تبديل السمة',
                        ),

                        // Custom actions
                        if (widget.actions != null) ...widget.actions!,
                      ],
                    ),
                  ),
                ),

                // Content area with scroll
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(AdminSpacing.lg),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
