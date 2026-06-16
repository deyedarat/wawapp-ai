import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../providers/admin_data_providers.dart';
import 'fullscreen_map_picker.dart';

/// Dialog for adding or editing a shared place.
/// Opens a fullscreen map picker when the user taps the map area.
class AddSharedPlaceDialog extends ConsumerStatefulWidget {
  final SharedPlace? existingPlace;

  const AddSharedPlaceDialog({super.key, this.existingPlace});

  @override
  ConsumerState<AddSharedPlaceDialog> createState() => _AddSharedPlaceDialogState();
}

class _AddSharedPlaceDialogState extends ConsumerState<AddSharedPlaceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _categoryController;

  LatLng? _selectedLocation;
  bool _isLoading = false;

  bool get _isEditing => widget.existingPlace != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingPlace?.name ?? '');
    _addressController = TextEditingController(text: widget.existingPlace?.address ?? '');
    _categoryController = TextEditingController(text: widget.existingPlace?.category ?? '');

    if (widget.existingPlace != null) {
      _selectedLocation = LatLng(widget.existingPlace!.latitude, widget.existingPlace!.longitude);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Row(
                  children: [
                    Icon(
                      _isEditing ? Icons.edit_location : Icons.add_location_alt,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isEditing ? 'تعديل المكان' : 'إضافة مكان مشترك',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 20),

                // Form fields
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم المكان *',
                          hintText: 'مثال: مصحة العافية',
                          prefixIcon: Icon(Icons.label),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          labelText: 'التصنيف',
                          hintText: 'مثال: مستشفى',
                          prefixIcon: Icon(Icons.category),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان *',
                    hintText: 'العنوان التفصيلي للمكان',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'العنوان مطلوب' : null,
                ),
                const SizedBox(height: 20),

                // Map selection button
                Text('الموقع على الخريطة *', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _openFullscreenMapPicker,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedLocation != null ? Colors.green : Colors.grey.shade300,
                        width: _selectedLocation != null ? 2 : 1,
                      ),
                      color: _selectedLocation != null
                          ? Colors.green.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.05),
                    ),
                    child: _selectedLocation != null
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 32),
                              const SizedBox(width: 12),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'تم تحديد الموقع ✓',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_selectedLocation!.latitude.toStringAsFixed(5)}, '
                                    '${_selectedLocation!.longitude.toStringAsFixed(5)}',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              const Icon(Icons.edit, color: Colors.grey, size: 20),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map, color: Colors.blue, size: 32),
                              SizedBox(width: 12),
                              Text(
                                'انقر لفتح الخريطة واختيار الموقع',
                                style: TextStyle(fontSize: 15, color: Colors.blue, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _onSubmit,
                      icon: _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(_isEditing ? Icons.save : Icons.add),
                      label: Text(_isEditing ? 'حفظ التعديلات' : 'إضافة المكان'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFullscreenMapPicker() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => FullscreenMapPicker(initialLocation: _selectedLocation),
        fullscreenDialog: true,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result;
      });
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى تحديد الموقع على الخريطة'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    final service = ref.read(adminSharedPlacesServiceProvider);

    bool success;
    if (_isEditing) {
      success = await service.updateSharedPlace(
        placeId: widget.existingPlace!.id,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        category: _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : null,
      );
    } else {
      final id = await service.createSharedPlace(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        category: _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : null,
      );
      success = id != null;
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'تم تحديث المكان بنجاح' : 'تم إضافة المكان بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(sharedPlacesStatsProvider);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء الحفظ'), backgroundColor: Colors.red));
      }
    }
  }
}
