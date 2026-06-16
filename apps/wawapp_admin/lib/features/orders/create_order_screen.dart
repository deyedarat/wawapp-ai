import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/colors.dart';
import '../../../providers/admin_data_providers.dart';
import 'widgets/map_location_picker.dart';

// ============================================================================
// Pricing – mirrors client app exactly
// ============================================================================

/// Shipment types – same as client app
enum AdminShipmentType {
  foodAndPerishables,
  furnitureAndHomeSetup,
  constructionMaterialsAndHeavyLoad,
  electricalAndHomeAppliances,
  generalGoodsAndBoxes,
  fragileOrSensitiveCargo,
}

extension AdminShipmentTypeExt on AdminShipmentType {
  String get arabicLabel {
    switch (this) {
      case AdminShipmentType.foodAndPerishables:
        return 'مواد غذائية وسريعة التلف';
      case AdminShipmentType.furnitureAndHomeSetup:
        return 'أثاث وتجهيزات منزلية';
      case AdminShipmentType.constructionMaterialsAndHeavyLoad:
        return 'مواد بناء وحمولات ثقيلة';
      case AdminShipmentType.electricalAndHomeAppliances:
        return 'أجهزة كهربائية وكهرومنزلية';
      case AdminShipmentType.generalGoodsAndBoxes:
        return 'بضائع عامة وكرتون';
      case AdminShipmentType.fragileOrSensitiveCargo:
        return 'حمولة حساسة / قابلة للكسر';
    }
  }

  double get multiplier {
    switch (this) {
      case AdminShipmentType.foodAndPerishables:
        return 1.10;
      case AdminShipmentType.furnitureAndHomeSetup:
        return 1.30;
      case AdminShipmentType.constructionMaterialsAndHeavyLoad:
        return 1.60;
      case AdminShipmentType.electricalAndHomeAppliances:
        return 1.25;
      case AdminShipmentType.generalGoodsAndBoxes:
        return 1.00;
      case AdminShipmentType.fragileOrSensitiveCargo:
        return 1.40;
    }
  }

  IconData get icon {
    switch (this) {
      case AdminShipmentType.foodAndPerishables:
        return Icons.restaurant;
      case AdminShipmentType.furnitureAndHomeSetup:
        return Icons.chair;
      case AdminShipmentType.constructionMaterialsAndHeavyLoad:
        return Icons.construction;
      case AdminShipmentType.electricalAndHomeAppliances:
        return Icons.electrical_services;
      case AdminShipmentType.generalGoodsAndBoxes:
        return Icons.inventory_2;
      case AdminShipmentType.fragileOrSensitiveCargo:
        return Icons.warning_amber;
    }
  }

  Color get color {
    switch (this) {
      case AdminShipmentType.foodAndPerishables:
        return Colors.green;
      case AdminShipmentType.furnitureAndHomeSetup:
        return Colors.brown;
      case AdminShipmentType.constructionMaterialsAndHeavyLoad:
        return Colors.orange;
      case AdminShipmentType.electricalAndHomeAppliances:
        return Colors.blue;
      case AdminShipmentType.generalGoodsAndBoxes:
        return Colors.grey;
      case AdminShipmentType.fragileOrSensitiveCargo:
        return Colors.red;
    }
  }

  static AdminShipmentType get defaultType =>
      AdminShipmentType.generalGoodsAndBoxes;
}

/// Cargo weight – same as client app
enum AdminCargoWeight {
  halfTon,
  oneTon,
  oneAndHalfTon,
  twoTons,
}

extension AdminCargoWeightExt on AdminCargoWeight {
  double get tons {
    switch (this) {
      case AdminCargoWeight.halfTon:
        return 0.5;
      case AdminCargoWeight.oneTon:
        return 1.0;
      case AdminCargoWeight.oneAndHalfTon:
        return 1.5;
      case AdminCargoWeight.twoTons:
        return 2.0;
    }
  }

  int get costMRU {
    switch (this) {
      case AdminCargoWeight.halfTon:
        return 70;
      case AdminCargoWeight.oneTon:
        return 140;
      case AdminCargoWeight.oneAndHalfTon:
        return 210;
      case AdminCargoWeight.twoTons:
        return 280;
    }
  }

  String get arabicLabel {
    switch (this) {
      case AdminCargoWeight.halfTon:
        return 'نصف طن';
      case AdminCargoWeight.oneTon:
        return 'طن';
      case AdminCargoWeight.oneAndHalfTon:
        return 'طن ونصف';
      case AdminCargoWeight.twoTons:
        return 'طنان';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminCargoWeight.halfTon:
        return Icons.fitness_center;
      case AdminCargoWeight.oneTon:
        return Icons.scale;
      case AdminCargoWeight.oneAndHalfTon:
        return Icons.scale;
      case AdminCargoWeight.twoTons:
        return Icons.local_shipping;
    }
  }

  static AdminCargoWeight get defaultWeight => AdminCargoWeight.halfTon;
}

/// Full pricing config – mirrors client exactly
class AdminPricingConfig {
  static const int base = 60;
  static const int perKm = 20;
  static const int minFare = 100;
  static const double antigravityMultiplier = 2.2;
  static const int perTonMRU = 140;

  static int roundTo5(num v) => (v / 5).round() * 5;

  static ({
    int base,
    int distancePart,
    int rawTotal,
    double multiplier,
    int rounded,
    int weightCost,
    int total,
  }) computeBreakdown(
    double km,
    AdminShipmentType shipmentType,
    AdminCargoWeight cargoWeight,
  ) {
    const b = base;
    final distancePart = (perKm * km).round();
    final rawTotal = b + distancePart;

    final multiplier = shipmentType.multiplier;
    final afterShipment = rawTotal * multiplier;
    final afterAntigravity = afterShipment * antigravityMultiplier;

    final withMin =
        afterAntigravity < minFare ? minFare.toDouble() : afterAntigravity;
    final rounded = roundTo5(withMin);

    final weightCost = cargoWeight.costMRU;
    final total = rounded + weightCost;

    return (
      base: b,
      distancePart: distancePart,
      rawTotal: rawTotal,
      multiplier: multiplier,
      rounded: rounded,
      weightCost: weightCost,
      total: total,
    );
  }

  /// Calculate distance using Haversine
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

// ============================================================================
// Create Order Screen
// ============================================================================

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
  bool _isCreating = false;

  AdminShipmentType _shipmentType = AdminShipmentTypeExt.defaultType;
  AdminCargoWeight _cargoWeight = AdminCargoWeightExt.defaultWeight;

  @override
  void dispose() {
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  ({
    int base,
    int distancePart,
    int rawTotal,
    double multiplier,
    int rounded,
    int weightCost,
    int total,
  })? get _breakdown {
    if (_distanceKm == null) return null;
    return AdminPricingConfig.computeBreakdown(
      _distanceKm!,
      _shipmentType,
      _cargoWeight,
    );
  }

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
        _recalculateDistance();
      });
    }
  }

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
        _recalculateDistance();
      });
    }
  }

  void _recalculateDistance() {
    if (_pickupLocation != null && _dropoffLocation != null) {
      final distance = AdminPricingConfig.calculateDistance(
        _pickupLocation!.latitude,
        _pickupLocation!.longitude,
        _dropoffLocation!.latitude,
        _dropoffLocation!.longitude,
      );
      setState(() => _distanceKm = distance);
    } else {
      setState(() => _distanceKm = null);
    }
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickupLocation == null || _dropoffLocation == null) {
      _showSnack('الرجاء تحديد موقع الاستلام والتسليم', isError: true);
      return;
    }

    setState(() => _isCreating = true);

    try {
      final bd = _breakdown!;
      final service = ref.read(adminOrdersServiceProvider);
      final orderId = await service.createManualOrder(
        clientPhone: '+222${_phoneController.text.trim()}',
        pickupAddress: _pickupLocation!.address,
        dropoffAddress: _dropoffLocation!.address,
        distanceKm: _distanceKm!,
        price: bd.total.toDouble(),
        pickupLat: _pickupLocation!.latitude,
        pickupLng: _pickupLocation!.longitude,
        dropoffLat: _dropoffLocation!.latitude,
        dropoffLng: _dropoffLocation!.longitude,
        weightTons: _cargoWeight.tons,
        shipmentType: _shipmentType.name,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        if (orderId != null) {
          _showSnack('تم إنشاء الطلب بنجاح: ${orderId.substring(0, 8)}…');
          Navigator.of(context).pop(true);
        } else {
          _showSnack('فشل إنشاء الطلب', isError: true);
        }
      }
    } catch (e) {
      if (mounted) _showSnack('خطأ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : AdminAppColors.successLight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bd = _breakdown;

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
            // ── Client Info ──────────────────────────────────────────────
            _sectionHeader('معلومات العميل', Icons.person_outline),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'رقم هاتف العميل',
                prefixText: '+222 ',
                prefixIcon: const Icon(Icons.phone),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.isEmpty) return 'الرجاء إدخال رقم الهاتف';
                if (v.length < 8) return 'رقم الهاتف غير صحيح';
                return null;
              },
            ),

            const SizedBox(height: 32),

            // ── Locations ────────────────────────────────────────────────
            _sectionHeader('المواقع', Icons.map_outlined),
            const SizedBox(height: 16),
            _buildLocationCard(
              title: 'موقع الاستلام',
              location: _pickupLocation,
              icon: Icons.trip_origin,
              color: const Color(0xFF00C853),
              onTap: _selectPickupLocation,
            ),
            const SizedBox(height: 12),
            _buildLocationCard(
              title: 'موقع التسليم',
              location: _dropoffLocation,
              icon: Icons.location_on,
              color: Colors.red,
              onTap: _selectDropoffLocation,
            ),

            const SizedBox(height: 32),

            // ── Shipment Type ────────────────────────────────────────────
            _sectionHeader('نوع الشحنة', Icons.category_outlined),
            const SizedBox(height: 12),
            _buildShipmentTypeSelector(),

            const SizedBox(height: 24),

            // ── Cargo Weight ─────────────────────────────────────────────
            _sectionHeader('وزن الشحنة', Icons.scale_outlined),
            const SizedBox(height: 12),
            _buildWeightSelector(),

            const SizedBox(height: 32),

            // ── Price Summary ─────────────────────────────────────────────
            if (bd != null) ...[
              _buildPriceSummary(bd),
              const SizedBox(height: 32),
            ],

            // ── Notes ─────────────────────────────────────────────────────
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                prefixIcon: const Icon(Icons.note_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // ── Create Button ─────────────────────────────────────────────
            ElevatedButton(
              onPressed: _isCreating ? null : _createOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminAppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'إنشاء الطلب',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Section header ───────────────────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AdminAppColors.primaryGreen, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ── Location card ────────────────────────────────────────────────────────
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
              color: location != null ? color : Colors.grey[300]!, width: 2),
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
              child: Icon(icon, color: color, size: 28),
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
                        color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location?.address ?? 'اضغط لتحديد الموقع على الخريطة',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          location != null ? Colors.black87 : Colors.grey[500],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (location != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // ── Shipment type selector ───────────────────────────────────────────────
  Widget _buildShipmentTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AdminShipmentType.values.map((type) {
        final isSelected = _shipmentType == type;
        return GestureDetector(
          onTap: () => setState(() => _shipmentType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color:
                  isSelected ? type.color.withOpacity(0.15) : Colors.grey[50],
              border: Border.all(
                color: isSelected ? type.color : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(type.icon,
                    size: 18,
                    color: isSelected ? type.color : Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  type.arabicLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? type.color : Colors.grey[700],
                  ),
                ),
                if (type.multiplier != 1.0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: type.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+${((type.multiplier - 1) * 100).round()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: type.color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Weight selector ──────────────────────────────────────────────────────
  Widget _buildWeightSelector() {
    return Row(
      children: AdminCargoWeight.values.map((w) {
        final isSelected = _cargoWeight == w;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _cargoWeight = w),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AdminAppColors.primaryGreen.withOpacity(0.12)
                    : Colors.grey[50],
                border: Border.all(
                  color: isSelected
                      ? AdminAppColors.primaryGreen
                      : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    w.icon,
                    size: 22,
                    color: isSelected
                        ? AdminAppColors.primaryGreen
                        : Colors.grey[500],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    w.arabicLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? AdminAppColors.primaryGreen
                          : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '+${w.costMRU} MRU',
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? AdminAppColors.primaryGreen
                          : Colors.grey[500],
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Price summary ────────────────────────────────────────────────────────
  Widget _buildPriceSummary(
    ({
      int base,
      int distancePart,
      int rawTotal,
      double multiplier,
      int rounded,
      int weightCost,
      int total,
    }) bd,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminAppColors.primaryGreen.withOpacity(0.08),
            AdminAppColors.primaryGreen.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AdminAppColors.primaryGreen.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Total price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'السعر الإجمالي',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '${bd.total} MRU',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AdminAppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Distance
          _breakdownRow(
            'المسافة',
            '${_distanceKm!.toStringAsFixed(2)} كم',
          ),
          const SizedBox(height: 6),
          _breakdownRow('السعر الأساسي', '${bd.base} MRU'),
          const SizedBox(height: 6),
          _breakdownRow('تكلفة المسافة (${_distanceKm!.toStringAsFixed(2)} كم)',
              '${bd.distancePart} MRU'),
          if (bd.multiplier != 1.0) ...[
            const SizedBox(height: 6),
            _breakdownRow(
              'معامل نوع الشحنة',
              '× ${bd.multiplier.toStringAsFixed(2)}',
              valueColor: _shipmentType.color,
            ),
          ],
          const SizedBox(height: 6),
          _breakdownRow(
            'معامل التسعير الأساسي',
            '× ${AdminPricingConfig.antigravityMultiplier.toStringAsFixed(1)}',
            valueColor: Colors.deepPurple,
          ),
          const SizedBox(height: 6),
          _breakdownRow(
            'تكلفة الوزن (${_cargoWeight.arabicLabel})',
            '+ ${bd.weightCost} MRU',
            valueColor: Colors.orange[700],
          ),
          const Divider(height: 20),
          _breakdownRow(
            'الإجمالي',
            '${bd.total} MRU',
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ??
                (isBold ? AdminAppColors.primaryGreen : Colors.black87),
          ),
        ),
      ],
    );
  }
}
