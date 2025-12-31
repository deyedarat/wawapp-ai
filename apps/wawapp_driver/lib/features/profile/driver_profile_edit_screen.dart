import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core_shared/core_shared.dart';
import 'providers/driver_profile_providers.dart';
import '../auth/providers/auth_service_provider.dart';

class DriverProfileEditScreen extends ConsumerStatefulWidget {
  const DriverProfileEditScreen({super.key});

  @override
  ConsumerState<DriverProfileEditScreen> createState() => _DriverProfileEditScreenState();
}

class _DriverProfileEditScreenState extends ConsumerState<DriverProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  void _loadCurrentProfile() {
    final profileAsync = ref.read(driverProfileStreamProvider);
    profileAsync.whenData((profile) {
      if (profile != null) {
        _nameController.text = profile.name;
        _vehicleTypeController.text = profile.vehicleType ?? '';
        _vehiclePlateController.text = profile.vehiclePlate ?? '';
        _vehicleColorController.text = profile.vehicleColor ?? '';
        _cityController.text = profile.city ?? '';
        _regionController.text = profile.region ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vehicleTypeController.dispose();
    _vehiclePlateController.dispose();
    _vehicleColorController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authProvider);
    if (authState.user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطأ: المستخدم غير مسجل الدخول')),
        );
      }
      return;
    }

    final currentProfileAsync = ref.read(driverProfileStreamProvider);
    final currentProfile = currentProfileAsync.value;

    final now = DateTime.now();
    final profile = DriverProfile(
      id: authState.user!.uid,
      name: _nameController.text.trim(),
      phone: authState.user!.phoneNumber ?? '',
      photoUrl: currentProfile?.photoUrl,
      vehicleType: _vehicleTypeController.text.trim().isEmpty ? null : _vehicleTypeController.text.trim(),
      vehiclePlate: _vehiclePlateController.text.trim().isEmpty ? null : _vehiclePlateController.text.trim(),
      vehicleColor: _vehicleColorController.text.trim().isEmpty ? null : _vehicleColorController.text.trim(),
      city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      region: _regionController.text.trim().isEmpty ? null : _regionController.text.trim(),
      isVerified: currentProfile?.isVerified ?? false,
      isOnline: currentProfile?.isOnline ?? false,
      rating: currentProfile?.rating ?? 0.0,
      totalTrips: currentProfile?.totalTrips ?? 0,
      createdAt: currentProfile?.createdAt ?? now,
      updatedAt: now,
    );

    if (currentProfile == null) {
      await ref.read(driverProfileNotifierProvider.notifier).createProfile(profile);
    } else {
      await ref.read(driverProfileNotifierProvider.notifier).updateProfile(profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(driverProfileNotifierProvider);

    ref.listen(driverProfileNotifierProvider, (previous, next) {
      if (previous?.isLoading == true && next.isLoading == false) {
        if (next.error == null) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ الملف الشخصي بنجاح')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في الحفظ: ${next.error}')),
          );
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: updateState.isLoading ? null : _saveProfile,
            child: updateState.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('حفظ'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile completeness warning banner
              Consumer(
                builder: (context, ref, child) {
                  final profileAsync = ref.watch(driverProfileStreamProvider);
                  return profileAsync.when(
                    data: (profile) {
                      if (profile != null && !profile.isCompleteForOrders) {
                        final missing = profile.missingRequiredFields;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.orange, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'يجب إكمال المعلومات التالية للاتصال:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      missing.join('، '),
                                      style: const TextStyle(color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
              _buildSection('المعلومات الشخصية', [
                _buildTextField(
                  controller: _nameController,
                  label: 'الاسم *',
                  icon: Icons.person,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الاسم مطلوب';
                    }
                    if (value.trim().length < 3) {
                      return 'الاسم يجب أن يكون 3 أحرف على الأقل';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _cityController,
                  label: 'المدينة *',
                  icon: Icons.location_city,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'المدينة مطلوبة للاتصال';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _regionController,
                  label: 'المنطقة',
                  icon: Icons.location_on,
                ),
              ]),
              const SizedBox(height: 24),
              _buildSection('معلومات السيارة', [
                _buildTextField(
                  controller: _vehicleTypeController,
                  label: 'نوع السيارة *',
                  icon: Icons.directions_car,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'نوع السيارة مطلوب للاتصال';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _vehiclePlateController,
                  label: 'رقم اللوحة *',
                  icon: Icons.confirmation_number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'رقم اللوحة مطلوب للاتصال';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _vehicleColorController,
                  label: 'لون السيارة',
                  icon: Icons.palette,
                ),
              ]),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: updateState.isLoading ? null : _saveProfile,
                  child: updateState.isLoading
                      ? const CircularProgressIndicator()
                      : const Text('حفظ التغييرات'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: updateState.isLoading ? null : () => context.pop(),
                  child: const Text('إلغاء'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}