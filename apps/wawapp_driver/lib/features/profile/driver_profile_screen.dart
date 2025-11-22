import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core_shared/core_shared.dart';
import '../../widgets/error_screen.dart';
import 'providers/driver_profile_providers.dart';

class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(driverProfileStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/profile/edit'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorScreen(
          message: AppError.from(error).toUserMessage(),
          onRetry: () => ref.refresh(driverProfileStreamProvider),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('لم يتم إعداد الملف الشخصي بعد'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/profile/edit'),
                    child: const Text('إنشاء الملف الشخصي'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileHeader(profile),
                const SizedBox(height: 24),
                _buildInfoSection('المعلومات الشخصية', [
                  _buildInfoTile('الاسم', profile.name, Icons.person),
                  _buildInfoTile('الهاتف', profile.phone, Icons.phone),
                  _buildInfoTile('المدينة', profile.city ?? 'غير محدد', Icons.location_city),
                  _buildInfoTile('المنطقة', profile.region ?? 'غير محدد', Icons.location_on),
                ]),
                const SizedBox(height: 16),
                _buildInfoSection('معلومات السيارة', [
                  _buildInfoTile('نوع السيارة', profile.vehicleType ?? 'غير محدد', Icons.directions_car),
                  _buildInfoTile('رقم اللوحة', profile.vehiclePlate ?? 'غير محدد', Icons.confirmation_number),
                  _buildInfoTile('اللون', profile.vehicleColor ?? 'غير محدد', Icons.palette),
                ]),
                const SizedBox(height: 16),
                _buildInfoSection('الإحصائيات', [
                  _buildInfoTile('التقييم', '${profile.rating.toStringAsFixed(1)} ⭐', Icons.star, readOnly: true),
                  _buildInfoTile('عدد الرحلات', '${profile.totalTrips}', Icons.route, readOnly: true),
                  _buildInfoTile('حالة التحقق', profile.isVerified ? 'تم التحقق ✓' : 'لم يتم التحقق', Icons.verified, readOnly: true),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(DriverProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
              child: profile.photoUrl == null ? Text(profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'S') : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.phone,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: profile.isVerified ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      profile.isVerified ? 'تم التحقق' : 'في انتظار التحقق',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: readOnly ? Colors.grey : null),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: readOnly ? Colors.grey : Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: readOnly ? Colors.grey[700] : null,
                  ),
                ),
              ],
            ),
          ),
          if (readOnly) const Icon(Icons.lock, size: 16, color: Colors.grey),
        ],
      ),
    );
  }
}