import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/order.dart' as app_order;
import '../../../services/location_service.dart';
import '../../../services/orders_service.dart';
import 'dart:math';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final _ordersService = OrdersService();
  final _locationService = LocationService.instance;
  Position? _currentPosition;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      _currentPosition = await _locationService.getCurrentPosition();
      setState(() {});
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      await _ordersService.acceptOrder(orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم قبول الطلب بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'خطأ: ${e.toString().contains('already taken') ? 'تم أخذ الطلب بالفعل' : e.toString()}')),
      );
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.nearby_requests),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _initLocation,
            ),
          ],
        ),
        body: _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('خطأ في الموقع: $_error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _initLocation,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              )
            : _currentPosition == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<app_order.Order>>(
                    stream: _ordersService.getNearbyOrders(_currentPosition!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('خطأ: ${snapshot.error}'),
                        );
                      }
                      final orders = snapshot.data ?? [];
                      if (orders.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('لا توجد طلبات قريبة'),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final distance = _calculateDistance(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                            order.pickup.lat,
                            order.pickup.lng,
                          );
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.local_shipping),
                              title: Text(
                                  'طلب #${order.id.substring(order.id.length - 6)}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'المسافة: ${distance.toStringAsFixed(1)} كم'),
                                  Text('من: ${order.pickup.label}'),
                                  Text('إلى: ${order.dropoff.label}'),
                                ],
                              ),
                              trailing: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${order.price} MRU'),
                                  const SizedBox(height: 4),
                                  ElevatedButton(
                                    onPressed: () => _acceptOrder(order.id),
                                    child: const Text('قبول'),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
