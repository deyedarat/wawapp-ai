import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/animations.dart';

/// Toast notification types
enum ToastType { success, error, warning, info }

/// Enhanced toast notification with animations, auto-dismiss, and action support.
/// Replaces basic SnackBar with a more professional notification system.
class AdminToast {
  AdminToast._();

  /// Show a toast notification
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onAction,
    String? actionLabel,
    bool dismissible = true,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        title: title,
        type: type,
        duration: duration,
        onAction: onAction,
        actionLabel: actionLabel,
        dismissible: dismissible,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  /// Convenience methods
  static void success(BuildContext context, String message, {String? title}) =>
      show(context, message: message, title: title, type: ToastType.success);

  static void error(BuildContext context, String message, {String? title}) =>
      show(context, message: message, title: title, type: ToastType.error, duration: const Duration(seconds: 6));

  static void warning(BuildContext context, String message, {String? title}) =>
      show(context, message: message, title: title, type: ToastType.warning);

  static void info(BuildContext context, String message, {String? title}) =>
      show(context, message: message, title: title, type: ToastType.info);
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final String? title;
  final ToastType type;
  final Duration duration;
  final VoidCallback? onAction;
  final String? actionLabel;
  final bool dismissible;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    this.title,
    required this.type,
    required this.duration,
    this.onAction,
    this.actionLabel,
    required this.dismissible,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.1, curve: Curves.easeOut),
        reverseCurve: const Interval(0.9, 1.0, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.15, curve: Curves.easeOutCubic),
      ),
    );

    _progressAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 1.0, curve: Curves.linear),
      ),
    );

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.stop();
    widget.onDismiss();
  }

  Color get _color {
    switch (widget.type) {
      case ToastType.success:
        return AdminAppColors.successLight;
      case ToastType.error:
        return AdminAppColors.errorLight;
      case ToastType.warning:
        return AdminAppColors.warningLight;
      case ToastType.info:
        return AdminAppColors.infoLight;
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.error:
        return Icons.error_rounded;
      case ToastType.warning:
        return Icons.warning_rounded;
      case ToastType.info:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Dismissible(
              key: UniqueKey(),
              direction: widget.dismissible ? DismissDirection.up : DismissDirection.none,
              onDismissed: (_) => _dismiss(),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480, minWidth: 300),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: isDark ? AdminAppColors.cardDark : AdminAppColors.cardLight,
                  borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
                  border: Border.all(color: _color.withOpacity(0.3), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: _color.withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Row(
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_icon, color: _color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          // Text
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.title != null)
                                  Text(
                                    widget.title!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: isDark ? AdminAppColors.textPrimaryDark : AdminAppColors.textPrimaryLight,
                                    ),
                                  ),
                                if (widget.title != null) const SizedBox(height: 2),
                                Text(
                                  widget.message,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AdminAppColors.textSecondaryDark
                                        : AdminAppColors.textSecondaryLight,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Action button
                          if (widget.onAction != null && widget.actionLabel != null)
                            TextButton(
                              onPressed: () {
                                widget.onAction!();
                                _dismiss();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: _color,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: Text(
                                widget.actionLabel!,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ),
                          // Close button
                          if (widget.dismissible)
                            IconButton(
                              onPressed: _dismiss,
                              icon: Icon(
                                Icons.close,
                                size: 16,
                                color: isDark ? AdminAppColors.textSecondaryDark : AdminAppColors.textSecondaryLight,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            ),
                        ],
                      ),
                    ),
                    // Progress bar
                    AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, _) {
                        return ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(AdminSpacing.radiusMd),
                            bottomRight: Radius.circular(AdminSpacing.radiusMd),
                          ),
                          child: LinearProgressIndicator(
                            value: _progressAnimation.value,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(_color.withOpacity(0.4)),
                            minHeight: 3,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
