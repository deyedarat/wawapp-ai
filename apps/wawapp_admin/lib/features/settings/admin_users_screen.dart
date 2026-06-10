import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rbac/admin_roles.dart';
import '../../core/rbac/permission_guard.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/status_badge.dart';

/// Admin user model
class AdminUser {
  final String id;
  final String name;
  final String email;
  final AdminRole role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.lastLogin,
  });
}

/// Mock provider for admin users (replace with Firestore in production)
final adminUsersProvider = StateProvider<List<AdminUser>>((ref) {
  return [
    AdminUser(
      id: '1',
      name: 'المسؤول الأعلى',
      email: 'admin@wawapp.mr',
      role: AdminRole.superAdmin,
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
      lastLogin: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AdminUser(
      id: '2',
      name: 'أحمد - مدير العمليات',
      email: 'ahmed@wawapp.mr',
      role: AdminRole.manager,
      isActive: true,
      createdAt: DateTime(2024, 3, 15),
      lastLogin: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AdminUser(
      id: '3',
      name: 'محمد - مشغّل',
      email: 'mohamed@wawapp.mr',
      role: AdminRole.operator,
      isActive: true,
      createdAt: DateTime(2024, 6, 10),
      lastLogin: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];
});

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdminScaffold(
      title: 'إدارة المسؤولين',
      actions: [
        PermissionGuard(
          permission: AdminPermission.manageAdmins,
          child: ElevatedButton.icon(
            onPressed: () => _showAddAdminDialog(context, ref),
            icon: const Icon(Icons.person_add),
            label: const Text('إضافة مسؤول'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminAppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Roles overview cards
          _buildRolesOverview(context, users, isDark),
          const SizedBox(height: AdminSpacing.xl),

          // Users table
          Text('المسؤولون', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AdminSpacing.md),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(AdminSpacing.md),
              child: Column(
                children: users.map((user) {
                  return _buildUserItem(context, ref, user, isDark);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolesOverview(BuildContext context, List<AdminUser> users, bool isDark) {
    return Row(
      children: AdminRole.values.map((role) {
        final count = users.where((u) => u.role == role).length;
        return Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AdminSpacing.md),
              child: Column(
                children: [
                  Icon(role.icon, color: _getRoleColor(role), size: 28),
                  const SizedBox(height: AdminSpacing.xs),
                  Text(
                    '$count',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: _getRoleColor(role)),
                  ),
                  const SizedBox(height: AdminSpacing.xxs),
                  Text(role.label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUserItem(BuildContext context, WidgetRef ref, AdminUser user, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AdminSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: isDark ? AdminAppColors.borderDark : AdminAppColors.borderLight, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            backgroundColor: _getRoleColor(user.role).withOpacity(0.1),
            child: Text(
              user.name.characters.first,
              style: TextStyle(color: _getRoleColor(user.role), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? AdminAppColors.textSecondaryDark : AdminAppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getRoleColor(user.role).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AdminSpacing.radiusFull),
              border: Border.all(color: _getRoleColor(user.role).withOpacity(0.3)),
            ),
            child: Text(
              user.role.label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _getRoleColor(user.role)),
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          // Status
          StatusBadge(
            label: user.isActive ? 'نشط' : 'معطّل',
            color: user.isActive ? AdminAppColors.successLight : AdminAppColors.offlineGrey,
            showDot: true,
            pulseDot: user.isActive,
          ),
          const SizedBox(width: AdminSpacing.md),
          // Actions
          PermissionGuard(
            permission: AdminPermission.manageRoles,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل الدور')),
                const PopupMenuItem(value: 'toggle', child: Text('تفعيل / تعطيل')),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('إزالة', style: TextStyle(color: Colors.red)),
                ),
              ],
              onSelected: (value) {
                // Handle action
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(AdminRole role) {
    switch (role) {
      case AdminRole.viewer:
        return AdminAppColors.textSecondaryLight;
      case AdminRole.operator:
        return AdminAppColors.activeBlue;
      case AdminRole.manager:
        return AdminAppColors.goldenYellow;
      case AdminRole.superAdmin:
        return AdminAppColors.primaryGreen;
    }
  }

  void _showAddAdminDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مسؤول جديد'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TextField(
                decoration: InputDecoration(labelText: 'الاسم', prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: AdminSpacing.md),
              const TextField(
                decoration: InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: AdminSpacing.md),
              DropdownButtonFormField<AdminRole>(
                decoration: const InputDecoration(labelText: 'الدور', prefixIcon: Icon(Icons.security)),
                items: AdminRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Row(children: [Icon(role.icon, size: 18), const SizedBox(width: 8), Text(role.label)]),
                  );
                }).toList(),
                onChanged: (_) {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إضافة المسؤول بنجاح'), backgroundColor: AdminAppColors.successLight),
              );
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}
