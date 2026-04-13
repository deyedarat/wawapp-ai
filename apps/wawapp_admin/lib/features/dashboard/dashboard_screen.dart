import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/stat_card.dart';
import '../../providers/admin_data_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  // ── Quick-action: Add Driver ─────────────────────────────────────
  void _showAddDriverDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('إضافة سائق جديد'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'الاسم الكامل',
                          hintText: 'مثال: محمد ولد أحمد',
                          prefixIcon: Icon(Icons.person)),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'الاسم مطلوب' : null,
                    ),
                    const SizedBox(height: AdminSpacing.md),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                          hintText: '+222XXXXXXXX',
                          prefixIcon: Icon(Icons.phone)),
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'رقم الهاتف مطلوب' : null,
                    ),
                    const SizedBox(height: AdminSpacing.md),
                    TextFormField(
                      controller: vehicleCtrl,
                      decoration: const InputDecoration(
                          labelText: 'نوع المركبة (اختياري)',
                          hintText: 'مثال: دراجة نارية',
                          prefixIcon: Icon(Icons.two_wheeler)),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AdminAppColors.primaryGreen,
                    foregroundColor: Colors.white),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);
                        try {
                          await FirebaseFirestore.instance
                              .collection('drivers')
                              .add({
                            'name': nameCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'vehicleType': vehicleCtrl.text.trim(),
                            'isOnline': false,
                            'isVerified': false,
                            'isBlocked': false,
                            'rating': 5.0,
                            'totalTrips': 0,
                            'createdAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Text('تمت إضافة السائق بنجاح'),
                              backgroundColor: AdminAppColors.successLight,
                            ));
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('خطأ: $e')));
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('إضافة'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Quick-action: Add Client ─────────────────────────────────────
  void _showAddClientDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('إضافة عميل جديد'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'الاسم الكامل',
                          hintText: 'مثال: فاطمة بنت محمد',
                          prefixIcon: Icon(Icons.person)),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'الاسم مطلوب' : null,
                    ),
                    const SizedBox(height: AdminSpacing.md),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                          hintText: '+222XXXXXXXX',
                          prefixIcon: Icon(Icons.phone)),
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'رقم الهاتف مطلوب' : null,
                    ),
                    const SizedBox(height: AdminSpacing.md),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني (اختياري)',
                          hintText: 'example@email.com',
                          prefixIcon: Icon(Icons.email)),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AdminAppColors.activeBlue,
                    foregroundColor: Colors.white),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);
                        try {
                          await FirebaseFirestore.instance
                              .collection('clients')
                              .add({
                            'name': nameCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'isVerified': false,
                            'isBlocked': false,
                            'totalOrders': 0,
                            'createdAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Text('تمت إضافة العميل بنجاح'),
                              backgroundColor: AdminAppColors.successLight,
                            ));
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('خطأ: $e')));
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('إضافة'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return AdminScaffold(
      title: 'لوحة التحكم',
      child: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('خطأ في تحميل البيانات: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(dashboardStatsProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (stats) {
          final orderStats = stats['orders'] as Map<String, int>? ?? {};
          final driverStats = stats['drivers'] as Map<String, int>? ?? {};

          final totalDrivers = driverStats['total'] ?? 0;
          final onlineDrivers = driverStats['online'] ?? 0;
          final activeOrders = (orderStats['assigning'] ?? 0) +
              (orderStats['accepted'] ?? 0) +
              (orderStats['on_route'] ?? 0);
          final completedToday = orderStats['completed'] ?? 0;
          final cancelledToday = orderStats['cancelled'] ?? 0;

          final onlinePercent = totalDrivers > 0
              ? (onlineDrivers / totalDrivers * 100).toInt()
              : 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary stats grid
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'السائقون النشطون',
                        value: '$onlineDrivers',
                        icon: Icons.drive_eta,
                        color: AdminAppColors.onlineGreen,
                        subtitle: '$onlinePercent٪ متصلون',
                        onTap: () => context.go('/drivers'),
                      ),
                    ),
                    const SizedBox(width: AdminSpacing.md),
                    Expanded(
                      child: StatCard(
                        title: 'الطلبات الجارية',
                        value: '$activeOrders',
                        icon: Icons.local_shipping,
                        color: AdminAppColors.activeBlue,
                        subtitle: 'قيد التوصيل',
                        onTap: () => context.go('/orders'),
                      ),
                    ),
                    const SizedBox(width: AdminSpacing.md),
                    Expanded(
                      child: StatCard(
                        title: 'طلبات اليوم',
                        value: '$completedToday',
                        icon: Icons.check_circle,
                        color: AdminAppColors.successLight,
                        subtitle: 'مكتملة',
                      ),
                    ),
                    const SizedBox(width: AdminSpacing.md),
                    Expanded(
                      child: StatCard(
                        title: 'طلبات ملغاة',
                        value: '$cancelledToday',
                        icon: Icons.cancel,
                        color: AdminAppColors.errorLight,
                        subtitle: 'اليوم',
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AdminSpacing.xl),

              // Recent activity section
              Text('النشاط الأخير',
                  style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: AdminSpacing.md),

              Card(
                child: Padding(
                  padding: EdgeInsets.all(AdminSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildActivityItem(
                        context,
                        icon: Icons.add_circle,
                        color: AdminAppColors.successLight,
                        title: 'طلب جديد تم إنشاؤه',
                        subtitle: 'الطلب #12345 من نواكشوط إلى نواذيبو',
                        time: 'منذ 5 دقائق',
                      ),
                      Divider(height: AdminSpacing.lg),
                      _buildActivityItem(
                        context,
                        icon: Icons.drive_eta,
                        color: AdminAppColors.onlineGreen,
                        title: 'سائق جديد متصل',
                        subtitle: 'محمد ولد أحمد بدأ نوبته',
                        time: 'منذ 15 دقيقة',
                      ),
                      Divider(height: AdminSpacing.lg),
                      _buildActivityItem(
                        context,
                        icon: Icons.check_circle,
                        color: AdminAppColors.primaryGreen,
                        title: 'طلب مكتمل',
                        subtitle: 'الطلب #12344 تم تسليمه بنجاح',
                        time: 'منذ 30 دقيقة',
                      ),
                      Divider(height: AdminSpacing.lg),
                      _buildActivityItem(
                        context,
                        icon: Icons.cancel,
                        color: AdminAppColors.errorLight,
                        title: 'طلب ملغى',
                        subtitle: 'الطلب #12343 ألغاه العميل',
                        time: 'منذ ساعة',
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: AdminSpacing.xl),

              // Quick actions
              Row(children: [
                Expanded(
                  child: Text('إجراءات سريعة',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ]),
              SizedBox(height: AdminSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      context,
                      icon: Icons.add,
                      title: 'إضافة سائق',
                      color: AdminAppColors.primaryGreen,
                      onTap: () => _showAddDriverDialog(context),
                    ),
                  ),
                  SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: _buildQuickActionCard(
                      context,
                      icon: Icons.person_add,
                      title: 'إضافة عميل',
                      color: AdminAppColors.activeBlue,
                      onTap: () => _showAddClientDialog(context),
                    ),
                  ),
                  SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: _buildQuickActionCard(
                      context,
                      icon: Icons.settings,
                      title: 'الإعدادات',
                      color: AdminAppColors.textSecondaryLight,
                      onTap: () => context.go('/settings'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(AdminSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(width: AdminSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              SizedBox(height: AdminSpacing.xxs),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Text(
          time,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AdminAppColors.textSecondaryLight),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
        child: Padding(
          padding: EdgeInsets.all(AdminSpacing.lg),
          child: Column(
            children: [
              Icon(icon, color: color, size: 36),
              SizedBox(height: AdminSpacing.sm),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
