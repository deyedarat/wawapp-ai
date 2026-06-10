/// Admin Role-Based Access Control (RBAC) System
/// Defines roles, permissions, and access rules for the admin panel.
library;

import 'package:flutter/material.dart';

/// Available admin roles (ordered by privilege level)
enum AdminRole {
  viewer, // Can only view data
  operator, // Can manage orders and drivers
  manager, // Can manage all operations + reports
  superAdmin, // Full access including settings and user management
}

/// Permission categories for the admin panel
enum AdminPermission {
  // Dashboard
  viewDashboard,

  // Orders
  viewOrders,
  createOrder,
  cancelOrder,
  editOrder,
  exportOrders,

  // Drivers
  viewDrivers,
  editDriver,
  verifyDriver,
  suspendDriver,

  // Clients
  viewClients,
  editClient,

  // Live Ops
  viewLiveOps,

  // Reports
  viewReports,
  exportReports,

  // Finance
  viewFinance,
  managePayouts,
  manageWallets,

  // Notifications
  viewNotifications,
  sendNotification,

  // Settings
  viewSettings,
  editSettings,
  managePricing,
  manageZones,
  manageHours,

  // Security & Admin
  viewAuditLog,
  manageAdmins,
  manageRoles,
  accessSecuritySettings,
}

/// Role to permissions mapping
class AdminRolePermissions {
  AdminRolePermissions._();

  /// Get permissions for a given role
  static Set<AdminPermission> getPermissions(AdminRole role) {
    switch (role) {
      case AdminRole.viewer:
        return _viewerPermissions;
      case AdminRole.operator:
        return _operatorPermissions;
      case AdminRole.manager:
        return _managerPermissions;
      case AdminRole.superAdmin:
        return AdminPermission.values.toSet(); // Full access
    }
  }

  /// Check if a role has a specific permission
  static bool hasPermission(AdminRole role, AdminPermission permission) {
    return getPermissions(role).contains(permission);
  }

  /// Check if a role has ALL of the specified permissions
  static bool hasAllPermissions(AdminRole role, List<AdminPermission> permissions) {
    final rolePermissions = getPermissions(role);
    return permissions.every((p) => rolePermissions.contains(p));
  }

  /// Check if a role has ANY of the specified permissions
  static bool hasAnyPermission(AdminRole role, List<AdminPermission> permissions) {
    final rolePermissions = getPermissions(role);
    return permissions.any((p) => rolePermissions.contains(p));
  }

  // ─── Permission Sets ─────────────────────────────────────────

  static final Set<AdminPermission> _viewerPermissions = {
    AdminPermission.viewDashboard,
    AdminPermission.viewOrders,
    AdminPermission.viewDrivers,
    AdminPermission.viewClients,
    AdminPermission.viewLiveOps,
    AdminPermission.viewReports,
    AdminPermission.viewNotifications,
  };

  static final Set<AdminPermission> _operatorPermissions = {
    ..._viewerPermissions,
    AdminPermission.createOrder,
    AdminPermission.cancelOrder,
    AdminPermission.editOrder,
    AdminPermission.editDriver,
    AdminPermission.verifyDriver,
    AdminPermission.editClient,
    AdminPermission.sendNotification,
    AdminPermission.exportOrders,
  };

  static final Set<AdminPermission> _managerPermissions = {
    ..._operatorPermissions,
    AdminPermission.suspendDriver,
    AdminPermission.exportReports,
    AdminPermission.viewFinance,
    AdminPermission.managePayouts,
    AdminPermission.manageWallets,
    AdminPermission.viewSettings,
    AdminPermission.editSettings,
    AdminPermission.managePricing,
    AdminPermission.manageZones,
    AdminPermission.manageHours,
    AdminPermission.viewAuditLog,
  };
}

/// Extension to provide human-readable Arabic labels
extension AdminRoleLabel on AdminRole {
  String get label {
    switch (this) {
      case AdminRole.viewer:
        return 'مشاهد';
      case AdminRole.operator:
        return 'مشغّل';
      case AdminRole.manager:
        return 'مدير';
      case AdminRole.superAdmin:
        return 'مسؤول أعلى';
    }
  }

  String get description {
    switch (this) {
      case AdminRole.viewer:
        return 'عرض البيانات فقط بدون تعديل';
      case AdminRole.operator:
        return 'إدارة الطلبات والسائقين';
      case AdminRole.manager:
        return 'إدارة كاملة مع التقارير والمالية';
      case AdminRole.superAdmin:
        return 'صلاحيات كاملة شاملة الإعدادات والمستخدمين';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminRole.viewer:
        return Icons.visibility;
      case AdminRole.operator:
        return Icons.person;
      case AdminRole.manager:
        return Icons.manage_accounts;
      case AdminRole.superAdmin:
        return Icons.admin_panel_settings;
    }
  }
}

extension AdminPermissionLabel on AdminPermission {
  String get label {
    switch (this) {
      case AdminPermission.viewDashboard:
        return 'عرض لوحة التحكم';
      case AdminPermission.viewOrders:
        return 'عرض الطلبات';
      case AdminPermission.createOrder:
        return 'إنشاء طلب';
      case AdminPermission.cancelOrder:
        return 'إلغاء طلب';
      case AdminPermission.editOrder:
        return 'تعديل طلب';
      case AdminPermission.exportOrders:
        return 'تصدير الطلبات';
      case AdminPermission.viewDrivers:
        return 'عرض السائقين';
      case AdminPermission.editDriver:
        return 'تعديل سائق';
      case AdminPermission.verifyDriver:
        return 'التحقق من سائق';
      case AdminPermission.suspendDriver:
        return 'إيقاف سائق';
      case AdminPermission.viewClients:
        return 'عرض العملاء';
      case AdminPermission.editClient:
        return 'تعديل عميل';
      case AdminPermission.viewLiveOps:
        return 'عرض المراقبة الحية';
      case AdminPermission.viewReports:
        return 'عرض التقارير';
      case AdminPermission.exportReports:
        return 'تصدير التقارير';
      case AdminPermission.viewFinance:
        return 'عرض المالية';
      case AdminPermission.managePayouts:
        return 'إدارة الدفعات';
      case AdminPermission.manageWallets:
        return 'إدارة المحافظ';
      case AdminPermission.viewNotifications:
        return 'عرض الإشعارات';
      case AdminPermission.sendNotification:
        return 'إرسال إشعار';
      case AdminPermission.viewSettings:
        return 'عرض الإعدادات';
      case AdminPermission.editSettings:
        return 'تعديل الإعدادات';
      case AdminPermission.managePricing:
        return 'إدارة التسعير';
      case AdminPermission.manageZones:
        return 'إدارة المناطق';
      case AdminPermission.manageHours:
        return 'إدارة ساعات العمل';
      case AdminPermission.viewAuditLog:
        return 'عرض سجل العمليات';
      case AdminPermission.manageAdmins:
        return 'إدارة المسؤولين';
      case AdminPermission.manageRoles:
        return 'إدارة الأدوار';
      case AdminPermission.accessSecuritySettings:
        return 'إعدادات الأمان';
    }
  }

  String get category {
    switch (this) {
      case AdminPermission.viewDashboard:
        return 'لوحة التحكم';
      case AdminPermission.viewOrders:
      case AdminPermission.createOrder:
      case AdminPermission.cancelOrder:
      case AdminPermission.editOrder:
      case AdminPermission.exportOrders:
        return 'الطلبات';
      case AdminPermission.viewDrivers:
      case AdminPermission.editDriver:
      case AdminPermission.verifyDriver:
      case AdminPermission.suspendDriver:
        return 'السائقون';
      case AdminPermission.viewClients:
      case AdminPermission.editClient:
        return 'العملاء';
      case AdminPermission.viewLiveOps:
        return 'المراقبة الحية';
      case AdminPermission.viewReports:
      case AdminPermission.exportReports:
        return 'التقارير';
      case AdminPermission.viewFinance:
      case AdminPermission.managePayouts:
      case AdminPermission.manageWallets:
        return 'المالية';
      case AdminPermission.viewNotifications:
      case AdminPermission.sendNotification:
        return 'الإشعارات';
      case AdminPermission.viewSettings:
      case AdminPermission.editSettings:
      case AdminPermission.managePricing:
      case AdminPermission.manageZones:
      case AdminPermission.manageHours:
        return 'الإعدادات';
      case AdminPermission.viewAuditLog:
      case AdminPermission.manageAdmins:
      case AdminPermission.manageRoles:
      case AdminPermission.accessSecuritySettings:
        return 'الأمان والإدارة';
    }
  }
}
