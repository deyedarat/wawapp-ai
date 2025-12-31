import 'package:core_shared/core_shared.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/safe_navigation.dart';
import 'providers/client_profile_providers.dart';

class ClientProfileEditScreen extends ConsumerStatefulWidget {
  const ClientProfileEditScreen({super.key});

  @override
  ConsumerState<ClientProfileEditScreen> createState() =>
      _ClientProfileEditScreenState();
}

class _ClientProfileEditScreenState
    extends ConsumerState<ClientProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedLanguage = 'ar';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentProfile();
    });
  }

  void _loadCurrentProfile() {
    final profileAsync = ref.read(clientProfileStreamProvider);
    profileAsync.whenData((profile) {
      if (profile != null) {
        _nameController.text = profile.name;
        _phoneController.text = profile.phone;
        _selectedLanguage = profile.preferredLanguage;
        setState(() {});
      } else {
        // Pre-fill phone from Firebase Auth if available
        final user = FirebaseAuth.instance.currentUser;
        if (user?.phoneNumber != null) {
          _phoneController.text = user!.phoneNumber!;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final now = DateTime.now();
      final profileAsync = ref.read(clientProfileStreamProvider);
      final currentProfile = profileAsync.value;

      final profile = ClientProfile(
        id: user.uid,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        photoUrl: currentProfile?.photoUrl,
        preferredLanguage: _selectedLanguage,
        totalTrips: currentProfile?.totalTrips ?? 0,
        averageRating: currentProfile?.averageRating ?? 0.0,
        createdAt: currentProfile?.createdAt ?? now,
        updatedAt: now,
      );

      if (currentProfile == null) {
        await ref
            .read(clientProfileNotifierProvider.notifier)
            .createProfile(profile);
      } else {
        await ref
            .read(clientProfileNotifierProvider.notifier)
            .updateProfile(profile);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الملف الشخصي بنجاح')),
        );
        context.safePop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في حفظ الملف الشخصي: $e')),
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
    final updateState = ref.watch(clientProfileNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال الاسم';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال رقم الهاتف';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedLanguage,
                decoration: const InputDecoration(
                  labelText: 'اللغة المفضلة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                ),
                items: const [
                  DropdownMenuItem(value: 'ar', child: Text('العربية')),
                  DropdownMenuItem(value: 'fr', child: Text('الفرنسية')),
                  DropdownMenuItem(value: 'en', child: Text('الإنجليزية')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedLanguage = value);
                  }
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || updateState.isLoading)
                      ? null
                      : _saveProfile,
                  child: (_isLoading || updateState.isLoading)
                      ? const CircularProgressIndicator()
                      : const Text('حفظ'),
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
}
