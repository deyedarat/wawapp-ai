import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core_shared/core_shared.dart';
import 'providers/client_profile_providers.dart';

class ClientProfileScreen extends ConsumerWidget {
  const ClientProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(clientProfileStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('خطأ في تحميل الملف الشخصي: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(clientProfileStreamProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return _buildNoProfileView(context);
          }
          return _buildProfileView(context, profile);
        },
      ),
    );
  }

  Widget _buildNoProfileView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'لم يتم إعداد الملف الشخصي بعد',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push('/profile/edit'),
            child: const Text('إعداد الملف الشخصي'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileView(BuildContext context, ClientProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: profile.photoUrl != null
                        ? NetworkImage(profile.photoUrl!)
                        : null,
                    child: profile.photoUrl == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('الاسم', profile.name),
                  _buildInfoRow('الهاتف', profile.phone),
                  _buildInfoRow('اللغة المفضلة', _getLanguageLabel(profile.preferredLanguage)),
                  _buildInfoRow('عدد الرحلات', profile.totalTrips.toString()),
                  _buildInfoRow('التقييم', profile.averageRating.toStringAsFixed(1)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push('/profile/edit'),
                      child: const Text('تعديل الملف الشخصي'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('المواقع المحفوظة'),
              subtitle: const Text('إدارة المواقع المفضلة لديك'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => context.push('/profile/locations'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getLanguageLabel(String languageCode) {
    switch (languageCode) {
      case 'ar':
        return 'العربية';
      case 'fr':
        return 'الفرنسية';
      case 'en':
        return 'الإنجليزية';
      default:
        return languageCode;
    }
  }
}