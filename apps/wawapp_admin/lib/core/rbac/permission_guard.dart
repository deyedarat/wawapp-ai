import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_roles.dart';

/// Provider for the current admin user's role.
/// This should be set from Firestore custom claims or user document.
final currentAdminRoleProvider = StateProvider<AdminRole>((ref) {
  // Default to superAdmin for now — in production, this would be fetched
  // from Firebase Auth custom claims or Firestore admin document
  return AdminRole.superAdmin;
});

/// Widget that conditionally shows its child based on permission.
/// If the current user doesn't have the required permission,
/// it shows a fallback widget or nothing.
class PermissionGuard extends ConsumerWidget {
  final AdminPermission permission;
  final Widget child;
  final Widget? fallback;
  final bool showLocked;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
    this.showLocked = false,
  });

  /// Guard requiring ANY of the specified permissions
  factory PermissionGuard.any({
    Key? key,
    required List<AdminPermission> permissions,
    required Widget child,
    Widget? fallback,
  }) = _AnyPermissionGuard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentAdminRoleProvider);
    final hasAccess = AdminRolePermissions.hasPermission(role, permission);

    if (hasAccess) return child;
    if (fallback != null) return fallback!;
    if (showLocked) return _buildLockedWidget(context);
    return const SizedBox.shrink();
  }

  Widget _buildLockedWidget(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: AbsorbPointer(
        child: Stack(
          children: [
            child,
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Icon(Icons.lock_outline, size: 24, color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal widget for "any permission" guard
class _AnyPermissionGuard extends PermissionGuard {
  final List<AdminPermission> permissions;

  const _AnyPermissionGuard({super.key, required this.permissions, required super.child, super.fallback})
    : super(permission: AdminPermission.viewDashboard);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentAdminRoleProvider);
    final hasAccess = AdminRolePermissions.hasAnyPermission(role, permissions);

    if (hasAccess) return child;
    if (fallback != null) return fallback!;
    return const SizedBox.shrink();
  }
}

/// Extension on WidgetRef for convenient permission checks
extension PermissionCheckExtension on WidgetRef {
  /// Check if current admin has a specific permission
  bool hasPermission(AdminPermission permission) {
    final role = watch(currentAdminRoleProvider);
    return AdminRolePermissions.hasPermission(role, permission);
  }

  /// Check if current admin has ALL specified permissions
  bool hasAllPermissions(List<AdminPermission> permissions) {
    final role = watch(currentAdminRoleProvider);
    return AdminRolePermissions.hasAllPermissions(role, permissions);
  }

  /// Check if current admin has ANY of the specified permissions
  bool hasAnyPermission(List<AdminPermission> permissions) {
    final role = watch(currentAdminRoleProvider);
    return AdminRolePermissions.hasAnyPermission(role, permissions);
  }

  /// Get the current admin role
  AdminRole get currentRole => watch(currentAdminRoleProvider);
}
