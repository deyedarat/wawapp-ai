import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';

// ---------- Model ----------
class DeliveryPriceConfig {
  final String id;
  final String name;
  final double baseFare;
  final double perKmRate;
  final double minimumFare;
  final bool isActive;

  DeliveryPriceConfig({
    required this.id,
    required this.name,
    required this.baseFare,
    required this.perKmRate,
    required this.minimumFare,
    required this.isActive,
  });

  factory DeliveryPriceConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DeliveryPriceConfig(
      id: doc.id,
      name: data['name'] ?? 'غير محدد',
      baseFare: (data['baseFare'] ?? 0).toDouble(),
      perKmRate: (data['perKmRate'] ?? 0).toDouble(),
      minimumFare: (data['minimumFare'] ?? 0).toDouble(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'baseFare': baseFare,
        'perKmRate': perKmRate,
        'minimumFare': minimumFare,
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

// ---------- Provider ----------
final deliveryPricingProvider =
    StreamProvider<List<DeliveryPriceConfig>>((ref) {
  return FirebaseFirestore.instance
      .collection('pricing_configs')
      .orderBy('name')
      .snapshots()
      .map((s) =>
          s.docs.map((d) => DeliveryPriceConfig.fromFirestore(d)).toList());
});

// ---------- Screen ----------
class DeliveryPricingScreen extends ConsumerWidget {
  const DeliveryPricingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricingAsync = ref.watch(deliveryPricingProvider);

    return AdminScaffold(
      title: 'أسعار التوصيل',
      actions: [
        ElevatedButton.icon(
          onPressed: () => _showAddPricingDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('إضافة تسعيرة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminAppColors.primaryGreen,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: AdminSpacing.md),
      ],
      child: pricingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildError(context, e),
        data: (configs) => _buildContent(context, configs),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object e) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('خطأ: $e'),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, List<DeliveryPriceConfig> configs) {
    if (configs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monetization_on_outlined,
                size: 64, color: AdminAppColors.textSecondaryLight),
            const SizedBox(height: 16),
            Text('لا توجد تسعيرات بعد',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showAddPricingDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('إضافة أول تسعيرة'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AdminSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          Card(
            color: AdminAppColors.primaryGreen.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(AdminSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AdminAppColors.primaryGreen, size: 20),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: Text(
                      'يمكنك إضافة تسعيرات مختلفة لأنواع التوصيل المتعددة. '
                      'السعر = الأجرة الأساسية + (سعر الكيلومتر × المسافة)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AdminSpacing.lg),

          // Pricing table
          Card(
            child: Table(
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: AdminAppColors.borderLight,
                  width: 1,
                ),
              ),
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
                4: FlexColumnWidth(1),
                5: FlexColumnWidth(2),
              },
              children: [
                // Header
                TableRow(
                  decoration: BoxDecoration(
                    color: AdminAppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AdminSpacing.radiusMd)),
                  ),
                  children: [
                    _tableHeader('اسم التسعيرة'),
                    _tableHeader('الأجرة الأساسية'),
                    _tableHeader('سعر الكيلومتر'),
                    _tableHeader('الحد الأدنى'),
                    _tableHeader('الحالة'),
                    _tableHeader('الإجراءات'),
                  ],
                ),
                // Data rows
                ...configs.map((config) => TableRow(
                      children: [
                        _tableCell(config.name),
                        _tableCell('${config.baseFare.toStringAsFixed(0)} MRU'),
                        _tableCell(
                            '${config.perKmRate.toStringAsFixed(1)} MRU/كم'),
                        _tableCell(
                            '${config.minimumFare.toStringAsFixed(0)} MRU'),
                        _tableCellWidget(
                          Switch(
                            value: config.isActive,
                            activeColor: AdminAppColors.primaryGreen,
                            onChanged: (val) => _togglePricing(config.id, val),
                          ),
                        ),
                        _tableCellWidget(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              color: AdminAppColors.activeBlue,
                              onPressed: () =>
                                  _showEditPricingDialog(context, config),
                              tooltip: 'تعديل',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: AdminAppColors.errorLight,
                              onPressed: () => _confirmDelete(context, config),
                              tooltip: 'حذف',
                            ),
                          ],
                        )),
                      ],
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(AdminSpacing.md),
      child: Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: AdminAppColors.primaryGreen),
      ),
    );
  }

  Widget _tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(AdminSpacing.md),
      child: Text(text),
    );
  }

  Widget _tableCellWidget(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.sm, vertical: AdminSpacing.xs),
      child: child,
    );
  }

  void _togglePricing(String id, bool value) {
    FirebaseFirestore.instance.collection('pricing_configs').doc(id).update({
      'isActive': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _showAddPricingDialog(BuildContext context) {
    _showPricingDialog(context, null);
  }

  void _showEditPricingDialog(
      BuildContext context, DeliveryPriceConfig config) {
    _showPricingDialog(context, config);
  }

  void _showPricingDialog(BuildContext context, DeliveryPriceConfig? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final baseFareCtrl = TextEditingController(
        text: existing?.baseFare.toStringAsFixed(0) ?? '');
    final perKmCtrl = TextEditingController(
        text: existing?.perKmRate.toStringAsFixed(1) ?? '');
    final minFareCtrl = TextEditingController(
        text: existing?.minimumFare.toStringAsFixed(0) ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'إضافة تسعيرة جديدة' : 'تعديل التسعيرة'),
        content: SizedBox(
          width: 450,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'اسم التسعيرة', hintText: 'مثال: توصيل عادي'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'الاسم مطلوب' : null,
                ),
                const SizedBox(height: AdminSpacing.md),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: baseFareCtrl,
                      decoration: const InputDecoration(
                          labelText: 'الأجرة الأساسية (MRU)'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || double.tryParse(v) == null
                          ? 'أدخل رقماً صحيحاً'
                          : null,
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: perKmCtrl,
                      decoration: const InputDecoration(
                          labelText: 'سعر الكيلومتر (MRU)'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || double.tryParse(v) == null
                          ? 'أدخل رقماً صحيحاً'
                          : null,
                    ),
                  ),
                ]),
                const SizedBox(height: AdminSpacing.md),
                TextFormField(
                  controller: minFareCtrl,
                  decoration:
                      const InputDecoration(labelText: 'الحد الأدنى (MRU)'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || double.tryParse(v) == null
                      ? 'أدخل رقماً صحيحاً'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AdminAppColors.primaryGreen,
                foregroundColor: Colors.white),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final data = {
                'name': nameCtrl.text.trim(),
                'baseFare': double.parse(baseFareCtrl.text),
                'perKmRate': double.parse(perKmCtrl.text),
                'minimumFare': double.parse(minFareCtrl.text),
                'isActive': true,
                'updatedAt': FieldValue.serverTimestamp(),
              };
              if (existing == null) {
                data['createdAt'] = FieldValue.serverTimestamp();
                await FirebaseFirestore.instance
                    .collection('pricing_configs')
                    .add(data);
              } else {
                await FirebaseFirestore.instance
                    .collection('pricing_configs')
                    .doc(existing.id)
                    .update(data);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'إضافة' : 'حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, DeliveryPriceConfig config) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف تسعيرة "${config.name}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('pricing_configs')
                  .doc(config.id)
                  .delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
