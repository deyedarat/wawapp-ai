import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:core_shared/core_shared.dart';
import 'providers/client_profile_providers.dart';

class SavedLocationsScreen extends ConsumerWidget {
  const SavedLocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(savedLocationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المواقع المحفوظة'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/profile/locations/add'),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: locationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('خطأ في تحميل المواقع: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(savedLocationsStreamProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (locations) {
          if (locations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد مواقع محفوظة',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'اضغط على + لإضافة موقع جديد',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
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
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(
                      context,
                      ref,
                      value,
                      location,
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('تعديل'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('حذف', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  onTap: () => context.push('/profile/locations/edit/${location.id}'),
                ),
              );
            },
          );
        },
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

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    SavedLocation location,
  ) {
    switch (action) {
      case 'edit':
        context.push('/profile/locations/edit/${location.id}');
        break;
      case 'delete':
        _showDeleteDialog(context, ref, location);
        break;
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    SavedLocation location,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الموقع'),
        content: Text('هل أنت متأكد من حذف "${location.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                try {
                  await ref
                      .read(savedLocationsNotifierProvider.notifier)
                      .deleteLocation(user.uid, location.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حذف الموقع بنجاح')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ في حذف الموقع: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}