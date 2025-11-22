import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import '../profile/providers/client_profile_providers.dart';
import 'pick_route_controller.dart';

enum SavedLocationSelectionMode { pickup, dropoff }

class SavedLocationSelectorSheet extends ConsumerWidget {
  final SavedLocationSelectionMode mode;
  final VoidCallback onLocationSelected;

  const SavedLocationSelectorSheet({
    super.key,
    required this.mode,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(savedLocationsStreamProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            mode == SavedLocationSelectionMode.pickup
                ? 'اختر موقع الاستلام المحفوظ'
                : 'اختر موقع التسليم المحفوظ',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: locationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('خطأ في تحميل المواقع المحفوظة'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إغلاق'),
                    ),
                  ],
                ),
              ),
              data: (locations) {
                if (locations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_off, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'لا توجد مواقع محفوظة بعد',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('إغلاق'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final location = locations[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getTypeColor(location.type),
                          child: Icon(
                            _getTypeIcon(location.type),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          location.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(location.type.toArabicLabel()),
                            Text(
                              location.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        onTap: () async {
                          await ref
                              .read(routePickerProvider.notifier)
                              .setLocationFromSavedLocation(
                                location,
                                mode == SavedLocationSelectionMode.pickup,
                              );
                          onLocationSelected();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(SavedLocationType type) {
    switch (type) {
      case SavedLocationType.home:
        return Colors.blue;
      case SavedLocationType.work:
        return Colors.orange;
      case SavedLocationType.other:
        return Colors.purple;
    }
  }

  IconData _getTypeIcon(SavedLocationType type) {
    switch (type) {
      case SavedLocationType.home:
        return Icons.home;
      case SavedLocationType.work:
        return Icons.work;
      case SavedLocationType.other:
        return Icons.location_on;
    }
  }
}