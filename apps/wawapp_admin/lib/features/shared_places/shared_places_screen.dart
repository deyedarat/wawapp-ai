import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../providers/admin_data_providers.dart';
import 'add_shared_place_dialog.dart';

class SharedPlacesScreen extends ConsumerStatefulWidget {
  const SharedPlacesScreen({super.key});

  @override
  ConsumerState<SharedPlacesScreen> createState() => _SharedPlacesScreenState();
}

class _SharedPlacesScreenState extends ConsumerState<SharedPlacesScreen> {
  bool? _activeFilter;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(sharedPlacesStreamProvider(_activeFilter));
    final statsAsync = ref.watch(sharedPlacesStatsProvider);

    return AdminScaffold(
      title: 'الأماكن المشتركة',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_location_alt),
          tooltip: 'إضافة مكان جديد',
          onPressed: () => _showAddPlaceDialog(context),
        ),
      ],
      onSearchChanged: (query) {
        setState(() => _searchQuery = query);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          statsAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (error, stack) => Text('خطأ في تحميل الإحصائيات: $error'),
            data: (stats) {
              final total = stats['total'] ?? 0;
              final active = stats['active'] ?? 0;
              final inactive = stats['inactive'] ?? 0;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildStatCard('الإجمالي', total, Icons.place, Colors.blue),
                  _buildStatCard('نشط', active, Icons.check_circle, Colors.green),
                  _buildStatCard('غير نشط', inactive, Icons.cancel, Colors.orange),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Filter row
          Row(
            children: [
              const Text('تصفية: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('الكل'),
                selected: _activeFilter == null,
                onSelected: (_) => setState(() => _activeFilter = null),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('نشط'),
                selected: _activeFilter == true,
                onSelected: (_) => setState(() => _activeFilter = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('غير نشط'),
                selected: _activeFilter == false,
                onSelected: (_) => setState(() => _activeFilter = false),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddPlaceDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('إضافة مكان'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminAppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Places list
          placesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('خطأ في تحميل الأماكن: $error')),
            data: (places) {
              // Apply search filter
              final filteredPlaces = _searchQuery.isEmpty
                  ? places
                  : places
                        .where(
                          (p) =>
                              p.name.contains(_searchQuery) ||
                              p.address.contains(_searchQuery) ||
                              (p.category?.contains(_searchQuery) ?? false),
                        )
                        .toList();

              if (filteredPlaces.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 48),
                      Icon(Icons.place_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty ? 'لا توجد نتائج للبحث' : 'لا توجد أماكن مشتركة بعد',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      if (_searchQuery.isEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _showAddPlaceDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('أضف أول مكان'),
                        ),
                    ],
                  ),
                );
              }

              return _buildPlacesTable(filteredPlaces);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacesTable(List<SharedPlace> places) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('الاسم')),
            DataColumn(label: Text('العنوان')),
            DataColumn(label: Text('التصنيف')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('تاريخ الإنشاء')),
            DataColumn(label: Text('إجراءات')),
          ],
          rows: places.map((place) {
            return DataRow(
              cells: [
                DataCell(Text(place.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(SizedBox(width: 200, child: Text(place.address, overflow: TextOverflow.ellipsis))),
                DataCell(Text(place.category ?? '—')),
                DataCell(
                  Chip(
                    label: Text(
                      place.isActive ? 'نشط' : 'غير نشط',
                      style: TextStyle(color: place.isActive ? Colors.green : Colors.orange, fontSize: 12),
                    ),
                    backgroundColor: place.isActive
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                  ),
                ),
                DataCell(Text(DateFormat('yyyy/MM/dd').format(place.createdAt))),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: 'تعديل',
                        onPressed: () => _showEditPlaceDialog(context, place),
                      ),
                      IconButton(
                        icon: Icon(place.isActive ? Icons.visibility_off : Icons.visibility, size: 20),
                        tooltip: place.isActive ? 'تعطيل' : 'تفعيل',
                        onPressed: () => _togglePlaceActive(place),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        tooltip: 'حذف',
                        onPressed: () => _confirmDelete(context, place),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAddPlaceDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const AddSharedPlaceDialog());
  }

  void _showEditPlaceDialog(BuildContext context, SharedPlace place) {
    showDialog(
      context: context,
      builder: (context) => AddSharedPlaceDialog(existingPlace: place),
    );
  }

  Future<void> _togglePlaceActive(SharedPlace place) async {
    final service = ref.read(adminSharedPlacesServiceProvider);
    await service.updateSharedPlace(placeId: place.id, isActive: !place.isActive);
  }

  void _confirmDelete(BuildContext context, SharedPlace place) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المكان'),
        content: Text('هل أنت متأكد من حذف "${place.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final service = ref.read(adminSharedPlacesServiceProvider);
              await service.deleteSharedPlace(place.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
