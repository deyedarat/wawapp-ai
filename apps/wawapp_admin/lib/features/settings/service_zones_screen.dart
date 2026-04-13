import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';

// ---------- Model ----------
class ServiceZone {
  final String id;
  final String name;
  final String city;
  final bool isActive;
  final String description;

  ServiceZone({
    required this.id,
    required this.name,
    required this.city,
    required this.isActive,
    required this.description,
  });

  factory ServiceZone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceZone(
      id: doc.id,
      name: data['name'] ?? 'غير محدد',
      city: data['city'] ?? '',
      isActive: data['isActive'] ?? true,
      description: data['description'] ?? '',
    );
  }
}

// ---------- Provider ----------
final serviceZonesProvider = StreamProvider<List<ServiceZone>>((ref) {
  return FirebaseFirestore.instance
      .collection('service_zones')
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map((d) => ServiceZone.fromFirestore(d)).toList());
});

// ---------- Screen ----------
class ServiceZonesScreen extends ConsumerWidget {
  const ServiceZonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(serviceZonesProvider);

    return AdminScaffold(
      title: 'المناطق المخدومة',
      actions: [
        ElevatedButton.icon(
          onPressed: () => _showZoneDialog(context, null),
          icon: const Icon(Icons.add_location),
          label: const Text('إضافة منطقة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminAppColors.primaryGreen,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: AdminSpacing.md),
      ],
      child: zonesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('خطأ في تحميل المناطق: $e'),
        ),
        data: (zones) => _buildContent(context, zones),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<ServiceZone> zones) {
    if (zones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined,
                size: 64, color: AdminAppColors.textSecondaryLight),
            const SizedBox(height: 16),
            Text('لا توجد مناطق مخدومة بعد',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showZoneDialog(context, null),
              icon: const Icon(Icons.add_location),
              label: const Text('إضافة أول منطقة'),
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
          // Stats row
          Row(
            children: [
              _buildStatChip(
                context,
                label: 'إجمالي المناطق',
                value: '${zones.length}',
                color: AdminAppColors.primaryGreen,
                icon: Icons.map,
              ),
              const SizedBox(width: AdminSpacing.md),
              _buildStatChip(
                context,
                label: 'مفعّلة',
                value: '${zones.where((z) => z.isActive).length}',
                color: AdminAppColors.successLight,
                icon: Icons.check_circle,
              ),
              const SizedBox(width: AdminSpacing.md),
              _buildStatChip(
                context,
                label: 'معطّلة',
                value: '${zones.where((z) => !z.isActive).length}',
                color: AdminAppColors.textSecondaryLight,
                icon: Icons.block,
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.lg),

          // Zones grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              crossAxisSpacing: AdminSpacing.md,
              mainAxisSpacing: AdminSpacing.md,
              childAspectRatio: 1.8,
            ),
            itemCount: zones.length,
            itemBuilder: (context, index) =>
                _buildZoneCard(context, zones[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AdminSpacing.lg, vertical: AdminSpacing.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: AdminSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold, color: color)),
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AdminAppColors.textSecondaryLight)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneCard(BuildContext context, ServiceZone zone) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AdminSpacing.sm),
                  decoration: BoxDecoration(
                    color: (zone.isActive
                            ? AdminAppColors.primaryGreen
                            : AdminAppColors.textSecondaryLight)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: zone.isActive
                        ? AdminAppColors.primaryGreen
                        : AdminAppColors.textSecondaryLight,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (zone.city.isNotEmpty)
                        Text(
                          zone.city,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: AdminAppColors.textSecondaryLight),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: zone.isActive,
                  activeColor: AdminAppColors.primaryGreen,
                  onChanged: (val) => _toggleZone(zone.id, val),
                ),
              ],
            ),
            if (zone.description.isNotEmpty) ...[
              const SizedBox(height: AdminSpacing.xs),
              Text(
                zone.description,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AdminAppColors.textSecondaryLight),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showZoneDialog(context, zone),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('تعديل'),
                  style: TextButton.styleFrom(
                      foregroundColor: AdminAppColors.activeBlue),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, zone),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('حذف'),
                  style: TextButton.styleFrom(
                      foregroundColor: AdminAppColors.errorLight),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleZone(String id, bool value) {
    FirebaseFirestore.instance.collection('service_zones').doc(id).update({
      'isActive': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _showZoneDialog(BuildContext context, ServiceZone? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final cityCtrl = TextEditingController(text: existing?.city ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'إضافة منطقة مخدومة' : 'تعديل المنطقة'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'اسم المنطقة',
                      hintText: 'مثال: نواكشوط - الكبة'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'الاسم مطلوب' : null,
                ),
                const SizedBox(height: AdminSpacing.md),
                TextFormField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(
                      labelText: 'المدينة', hintText: 'مثال: نواكشوط'),
                ),
                const SizedBox(height: AdminSpacing.md),
                TextFormField(
                  controller: descCtrl,
                  decoration:
                      const InputDecoration(labelText: 'الوصف (اختياري)'),
                  maxLines: 2,
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
                'city': cityCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'isActive': true,
                'updatedAt': FieldValue.serverTimestamp(),
              };
              if (existing == null) {
                data['createdAt'] = FieldValue.serverTimestamp();
                await FirebaseFirestore.instance
                    .collection('service_zones')
                    .add(data);
              } else {
                await FirebaseFirestore.instance
                    .collection('service_zones')
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

  void _confirmDelete(BuildContext context, ServiceZone zone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المنطقة "${zone.name}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('service_zones')
                  .doc(zone.id)
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
