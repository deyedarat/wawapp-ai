import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/colors.dart';
import '../../../providers/admin_data_providers.dart';
import 'widgets/map_location_picker.dart';

/// Pricing configuration (matching client app)
class PricingConfig {
  static const int base = 60;
  static const int perKm = 20;
  static const int minFare = 100;

  /// Calculate price based on distance
  static int calculatePrice(double distanceKm) {
    final distancePart = (perKm * distanceKm).round();
    final total = base + distancePart;
    final withMin = total < minFare ? minFare : total;
    // Round to nearest 5
    final rounded = (withMin / 5).round() * 5;
    return rounded;
  }

  /// Calculate distance between two points (Haversine formula)
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const Distance distance = Distance();
    return distance.as(
      LengthUnit.Kilometer,
      LatLng(lat1, lng1),
      LatLng(lat2, lng2),
    );
  }
}

/// Create Order Screen with Map Integration
class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  LocationData? _pickupLocation;
  LocationData? _dropoffLocation;
  double? _distanceKm;
  int? _calculatedPrice;
  bool _isCreating = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Open map picker for pickup location
  Future<void> _selectPickupLocation() async {
    final result = await Navigator.push<LocationData>(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPicker(
          title: 'اختر موقع الاستلام',
          initialLocation: _pickupLocation,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _pickupLocation = result;
        _recalculatePrice();
      });
    }
  }

  /// Open map picker for dropoff location
  Future<void> _selectDropoffLocation() async {
    final result = await Navigator.push<LocationData>(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPicker(
          title: 'اختر موقع التسليم',
          initialLocation: _dropoffLocation,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _dropoffLocation = result;
        _recalculatePrice();
      });
    }
  }

  /// Recalculate price when both locations are selected
  void _recalculatePrice() {
    if (_pickupLocation != null && _dropoffLocation != null) {
      final distance = PricingConfig.calculateDistance(
        _pickupLocation!.latitude,
        _pickupLocation!.longitude,
        _dropoffLocation!.latitude,
        _dropoffLocation!.longitude,
      );

      setState(() {
        _distanceKm = distance;
        _calculatedPrice = PricingConfig.calculatePrice(distance);
      });
    } else {
      setState(() {
        _distanceKm = null;
        _calculatedPrice = null;
      });
    }
  }

  /// Create the order
  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_pickupLocation == null || _dropoffLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء تحديد موقع الاستلام والتسليم'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final service = ref.read(adminOrdersServiceProvider);
      final orderId = await service.createManualOrder(
        clientPhone: '+222${_phoneController.text.trim()}',
        pickupAddress: _pickupLocation!.address,
        dropoffAddress: _dropoffLocation!.address,
        distanceKm: _distanceKm!,
        price: _calculatedPrice!.toDouble(),
        pickupLat: _pickupLocation!.latitude,
        pickupLng: _pickupLocation!.longitude,
        dropoffLat: _dropoffLocation!.latitude,
        dropoffLng: _dropoffLocation!.longitude,
      );

      if (mounted) {
        if (orderId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إنشاء الطلب بنجاح: ${orderId.substring(0, 8)}'),
              backgroundColor: AdminAppColors.successLight,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل إنشاء الطلب'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء طلب جديد'),
        backgroundColor: AdminAppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Header
            const Text(
              'معلومات العميل',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Phone number
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'رقم هاتف العميل',
                prefixText: '+222 ',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال رقم الهاتف';
                }
                if (value.length < 8) {
                  return 'رقم الهاتف غير صحيح';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Locations section
            const Text(
              'المواقع',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Pickup location
            _buildLocationCard(
              title: 'موقع الاستلام',
              location: _pickupLocation,
              icon: Icons.trip_origin,
              color: const Color(0xFF00C853),
              onTap: _selectPickupLocation,
            ),

            const SizedBox(height: 16),

            // Dropoff location
            _buildLocationCard(
              title: 'موقع التسليم',
              location: _dropoffLocation,
              icon: Icons.location_on,
              color: Colors.red,
              onTap: _selectDropoffLocation,
            ),

            const SizedBox(height: 32),

            // Price summary
            if (_calculatedPrice != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AdminAppColors.primaryGreen.withOpacity(0.1),
                      AdminAppColors.primaryGreen.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AdminAppColors.primaryGreen.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'المسافة:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${_distanceKm!.toStringAsFixed(2)} كم',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'السعر الإجمالي:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$_calculatedPrice MRU',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AdminAppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'السعر الأساسي: ${PricingConfig.base} MRU + ${PricingConfig.perKm} MRU/كم',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Notes (optional)
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                prefixIcon: const Icon(Icons.note),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // Create button
            ElevatedButton(
              onPressed: _isCreating ? null : _createOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminAppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'إنشاء الطلب',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required String title,
    required LocationData? location,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: location != null ? color : Colors.grey[300]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: location != null ? color.withOpacity(0.05) : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location?.address ?? 'اضغط لتحديد الموقع على الخريطة',
                    style: TextStyle(
                      fontSize: 13,
                      color: location != null ? Colors.black87 : Colors.grey[500],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (location != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
