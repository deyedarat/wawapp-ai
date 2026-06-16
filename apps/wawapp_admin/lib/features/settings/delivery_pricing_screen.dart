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
  final double antigravityMultiplier;
  final int perTonMRU;
  final Map<String, double> shipmentMultipliers;
  final Map<String, int> weightCosts;
  final bool isActive;

  DeliveryPriceConfig({
    required this.id,
    required this.name,
    required this.baseFare,
    required this.perKmRate,
    required this.minimumFare,
    required this.antigravityMultiplier,
    required this.perTonMRU,
    required this.shipmentMultipliers,
    required this.weightCosts,
    required this.isActive,
  });

  static const Map<String, double> defaultShipmentMultipliers = {
    'generalGoodsAndBoxes': 1.00,
    'foodAndPerishables': 1.10,
    'electricalAndHomeAppliances': 1.25,
    'furnitureAndHomeSetup': 1.30,
    'fragileOrSensitiveCargo': 1.40,
    'constructionMaterialsAndHeavyLoad': 1.60,
  };

  static const Map<String, int> defaultWeightCosts = {
    'halfTon': 70,
    'oneTon': 140,
    'oneAndHalfTon': 210,
    'twoTons': 280,
  };

  factory DeliveryPriceConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    Map<String, double> shipment = Map.from(defaultShipmentMultipliers);
    if (data['shipmentMultipliers'] is Map) {
      final raw = data['shipmentMultipliers'] as Map;
      for (final e in raw.entries) {
        shipment[e.key.toString()] = (e.value as num).toDouble();
      }
    }

    Map<String, int> weights = Map.from(defaultWeightCosts);
    if (data['weightCosts'] is Map) {
      final raw = data['weightCosts'] as Map;
      for (final e in raw.entries) {
        weights[e.key.toString()] = (e.value as num).toInt();
      }
    }

    return DeliveryPriceConfig(
      id: doc.id,
      name: data['name'] ?? 'غير محدد',
      baseFare: (data['baseFare'] ?? 0).toDouble(),
      perKmRate: (data['perKmRate'] ?? 0).toDouble(),
      minimumFare: (data['minimumFare'] ?? 0).toDouble(),
      antigravityMultiplier: (data['antigravityMultiplier'] ?? 2.2).toDouble(),
      perTonMRU: (data['perTonMRU'] ?? 140).toInt(),
      shipmentMultipliers: shipment,
      weightCosts: weights,
      isActive: data['isActive'] ?? true,
    );
  }
}

// ---------- Provider ----------
final deliveryPricingProvider = StreamProvider<List<DeliveryPriceConfig>>((ref) {
  return FirebaseFirestore.instance
      .collection('pricing_configs')
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map((d) => DeliveryPriceConfig.fromFirestore(d)).toList());
});

// ---------- Labels ----------
const _shipmentLabels = {
  'generalGoodsAndBoxes': 'بضائع عامة وكرتون',
  'foodAndPerishables': 'مواد غذائية وسريعة التلف',
  'electricalAndHomeAppliances': 'أجهزة كهربائية',
  'furnitureAndHomeSetup': 'أثاث ومنزليات',
  'fragileOrSensitiveCargo': 'حمولة حساسة/قابلة للكسر',
  'constructionMaterialsAndHeavyLoad': 'مواد بناء وحمولات ثقيلة',
};

const _weightLabels = {'halfTon': 'نصف طن', 'oneTon': 'طن', 'oneAndHalfTon': 'طن ونصف', 'twoTons': 'طنان'};

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
          onPressed: () => _showPricingDialog(context, null),
          icon: const Icon(Icons.add),
          label: const Text('إضافة تسعيرة'),
          style: ElevatedButton.styleFrom(backgroundColor: AdminAppColors.primaryGreen, foregroundColor: Colors.white),
        ),
        const SizedBox(width: AdminSpacing.md),
      ],
      child: pricingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (configs) => _buildContent(context, configs),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<DeliveryPriceConfig> configs) {
    if (configs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monetization_on_outlined, size: 64, color: AdminAppColors.textSecondaryLight),
            const SizedBox(height: 16),
            Text('لا توجد تسعيرات بعد', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showPricingDialog(context, null),
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
          Card(
            color: AdminAppColors.primaryGreen.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(AdminSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AdminAppColors.primaryGreen, size: 20),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: Text(
                      'السعر = تقريب((الأساسية + كم×سعر_الكم) × نوع_الشحنة × معامل_التسعير) + تكلفة_الوزن. '
                      'التغييرات تُطبق مباشرة على تطبيق العميل.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AdminSpacing.lg),
          ...configs.map((config) => _buildConfigCard(context, config)),
        ],
      ),
    );
  }

  Widget _buildConfigCard(BuildContext context, DeliveryPriceConfig config) {
    return Card(
      margin: const EdgeInsets.only(bottom: AdminSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(config.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Switch(
                  value: config.isActive,
                  activeColor: AdminAppColors.primaryGreen,
                  onChanged: (val) => _togglePricing(config.id, val),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  color: AdminAppColors.activeBlue,
                  onPressed: () => _showPricingDialog(context, config),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: AdminAppColors.errorLight,
                  onPressed: () => _confirmDelete(context, config),
                ),
              ],
            ),
            const Divider(),
            // Basic pricing row
            Wrap(
              spacing: 32,
              runSpacing: 8,
              children: [
                _infoChip('الأجرة الأساسية', '${config.baseFare.toStringAsFixed(0)} MRU'),
                _infoChip('سعر الكيلومتر', '${config.perKmRate.toStringAsFixed(1)} MRU/كم'),
                _infoChip('الحد الأدنى', '${config.minimumFare.toStringAsFixed(0)} MRU'),
                _infoChip('معامل التسعير', '×${config.antigravityMultiplier.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 16),
            // Shipment multipliers
            Text(
              'معاملات أنواع الشحنة',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: config.shipmentMultipliers.entries.map((e) {
                final label = _shipmentLabels[e.key] ?? e.key;
                return _infoChip(label, '×${e.value.toStringAsFixed(2)}');
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Weight costs
            Text(
              'تكاليف الأوزان',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: config.weightCosts.entries.map((e) {
                final label = _weightLabels[e.key] ?? e.key;
                return _infoChip(label, '${e.value} MRU');
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AdminAppColors.primaryGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _togglePricing(String id, bool value) {
    FirebaseFirestore.instance.collection('pricing_configs').doc(id).update({
      'isActive': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _showPricingDialog(BuildContext context, DeliveryPriceConfig? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final baseFareCtrl = TextEditingController(text: existing?.baseFare.toStringAsFixed(0) ?? '60');
    final perKmCtrl = TextEditingController(text: existing?.perKmRate.toStringAsFixed(1) ?? '20.0');
    final minFareCtrl = TextEditingController(text: existing?.minimumFare.toStringAsFixed(0) ?? '100');
    final antigravityCtrl = TextEditingController(text: existing?.antigravityMultiplier.toStringAsFixed(2) ?? '2.20');

    // Shipment multiplier controllers
    final shipmentCtrls = <String, TextEditingController>{};
    final shipmentDefaults = existing?.shipmentMultipliers ?? DeliveryPriceConfig.defaultShipmentMultipliers;
    for (final key in DeliveryPriceConfig.defaultShipmentMultipliers.keys) {
      shipmentCtrls[key] = TextEditingController(text: (shipmentDefaults[key] ?? 1.0).toStringAsFixed(2));
    }

    // Weight cost controllers
    final weightCtrls = <String, TextEditingController>{};
    final weightDefaults = existing?.weightCosts ?? DeliveryPriceConfig.defaultWeightCosts;
    for (final key in DeliveryPriceConfig.defaultWeightCosts.keys) {
      weightCtrls[key] = TextEditingController(text: (weightDefaults[key] ?? 0).toString());
    }

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'إضافة تسعيرة جديدة' : 'تعديل التسعيرة'),
        content: SizedBox(
          width: 550,
          height: 520,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Basic ---
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'اسم التسعيرة'),
                    validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: baseFareCtrl,
                          decoration: const InputDecoration(labelText: 'الأجرة الأساسية'),
                          keyboardType: TextInputType.number,
                          validator: (v) => double.tryParse(v ?? '') == null ? 'رقم' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: perKmCtrl,
                          decoration: const InputDecoration(labelText: 'سعر الكيلومتر'),
                          keyboardType: TextInputType.number,
                          validator: (v) => double.tryParse(v ?? '') == null ? 'رقم' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: minFareCtrl,
                          decoration: const InputDecoration(labelText: 'الحد الأدنى'),
                          keyboardType: TextInputType.number,
                          validator: (v) => double.tryParse(v ?? '') == null ? 'رقم' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: antigravityCtrl,
                          decoration: const InputDecoration(labelText: 'معامل التسعير'),
                          keyboardType: TextInputType.number,
                          validator: (v) => double.tryParse(v ?? '') == null ? 'رقم' : null,
                        ),
                      ),
                    ],
                  ),

                  // --- Shipment Multipliers ---
                  const SizedBox(height: 20),
                  Text(
                    'معاملات أنواع الشحنة',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AdminAppColors.primaryGreen),
                  ),
                  const SizedBox(height: 8),
                  ...shipmentCtrls.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextFormField(
                        controller: e.value,
                        decoration: InputDecoration(
                          labelText: _shipmentLabels[e.key] ?? e.key,
                          prefixText: '× ',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => double.tryParse(v ?? '') == null ? 'رقم' : null,
                      ),
                    ),
                  ),

                  // --- Weight Costs ---
                  const SizedBox(height: 20),
                  Text(
                    'تكاليف الأوزان (MRU)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AdminAppColors.primaryGreen),
                  ),
                  const SizedBox(height: 8),
                  ...weightCtrls.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextFormField(
                        controller: e.value,
                        decoration: InputDecoration(
                          labelText: _weightLabels[e.key] ?? e.key,
                          suffixText: 'MRU',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => int.tryParse(v ?? '') == null ? 'رقم' : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminAppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final shipmentMap = <String, double>{};
              for (final e in shipmentCtrls.entries) {
                shipmentMap[e.key] = double.parse(e.value.text);
              }

              final weightMap = <String, int>{};
              for (final e in weightCtrls.entries) {
                weightMap[e.key] = int.parse(e.value.text);
              }

              final data = <String, dynamic>{
                'name': nameCtrl.text.trim(),
                'baseFare': double.parse(baseFareCtrl.text),
                'perKmRate': double.parse(perKmCtrl.text),
                'minimumFare': double.parse(minFareCtrl.text),
                'antigravityMultiplier': double.parse(antigravityCtrl.text),
                'perTonMRU': weightMap['oneTon'] ?? 140,
                'shipmentMultipliers': shipmentMap,
                'weightCosts': weightMap,
                'isActive': existing?.isActive ?? true,
                'updatedAt': FieldValue.serverTimestamp(),
              };
              if (existing == null) {
                data['createdAt'] = FieldValue.serverTimestamp();
                await FirebaseFirestore.instance.collection('pricing_configs').add(data);
              } else {
                await FirebaseFirestore.instance.collection('pricing_configs').doc(existing.id).update(data);
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('pricing_configs').doc(config.id).delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
