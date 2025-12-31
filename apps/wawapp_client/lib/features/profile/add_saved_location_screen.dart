import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core_shared/core_shared.dart';
import 'providers/client_profile_providers.dart';
import '../auth/providers/auth_service_provider.dart';
import '../../core/navigation/safe_navigation.dart';

class AddSavedLocationScreen extends ConsumerStatefulWidget {
  final String? locationId;

  const AddSavedLocationScreen({super.key, this.locationId});

  @override
  ConsumerState<AddSavedLocationScreen> createState() =>
      _AddSavedLocationScreenState();
}

class _AddSavedLocationScreenState
    extends ConsumerState<AddSavedLocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  SavedLocationType _selectedType = SavedLocationType.other;
  bool _isLoading = false;
  SavedLocation? _existingLocation;

  bool get isEditing => widget.locationId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadExistingLocation();
    }
  }

  void _loadExistingLocation() async {
    final authState = ref.read(authProvider);
    if (authState.user == null) return;

    try {
      final locations = await ref
          .read(clientProfileRepositoryProvider)
          .getSavedLocations(authState.user!.uid);

      final location = locations.firstWhere(
        (loc) => loc.id == widget.locationId,
        orElse: () => throw Exception('الموقع غير موجود'),
      );

      setState(() {
        _existingLocation = location;
        _nameController.text = location.name;
        _addressController.text = location.address;
        _latController.text = location.latitude.toString();
        _lngController.text = location.longitude.toString();
        _selectedType = location.type;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الموقع: $e')),
        );
        context.safePop();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _saveLocation() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authProvider);
    if (authState.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المستخدم غير مسجل الدخول')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final location = SavedLocation(
        id: _existingLocation?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        userId: authState.user!.uid,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: double.parse(_latController.text.trim()),
        longitude: double.parse(_lngController.text.trim()),
        type: _selectedType,
        createdAt: _existingLocation?.createdAt ?? now,
        updatedAt: now,
      );

      if (isEditing) {
        await ref
            .read(savedLocationsNotifierProvider.notifier)
            .updateLocation(authState.user!.uid, location);
      } else {
        await ref
            .read(savedLocationsNotifierProvider.notifier)
            .addLocation(authState.user!.uid, location);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isEditing ? 'تم تحديث الموقع بنجاح' : 'تم إضافة الموقع بنجاح'),
          ),
        );
        context.safePop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في حفظ الموقع: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(savedLocationsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل الموقع' : 'إضافة موقع جديد'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              DropdownButtonFormField<SavedLocationType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'نوع الموقع',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: SavedLocationType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(_getTypeIcon(type)),
                        const SizedBox(width: 8),
                        Text(type.toArabicLabel()),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الموقع',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                  hintText: 'مثال: منزل العائلة، مكتب الشركة',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال اسم الموقع';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال العنوان';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(
                        labelText: 'خط العرض',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.my_location),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'مطلوب';
                        }
                        final lat = double.tryParse(value.trim());
                        if (lat == null || lat < -90 || lat > 90) {
                          return 'قيمة غير صحيحة';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      decoration: const InputDecoration(
                        labelText: 'خط الطول',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.place),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'مطلوب';
                        }
                        final lng = double.tryParse(value.trim());
                        if (lng == null || lng < -180 || lng > 180) {
                          return 'قيمة غير صحيحة';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'يمكنك الحصول على الإحداثيات من خرائط جوجل أو أي تطبيق خرائط آخر',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || updateState.isLoading)
                      ? null
                      : _saveLocation,
                  child: (_isLoading || updateState.isLoading)
                      ? const CircularProgressIndicator()
                      : Text(isEditing ? 'تحديث الموقع' : 'إضافة الموقع'),
                ),
              ),
              if (updateState.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  'خطأ: ${updateState.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
