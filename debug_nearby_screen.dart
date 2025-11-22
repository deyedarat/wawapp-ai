import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:developer' as dev;

// This is a debug version to test the nearby orders issue
class DebugNearbyScreen extends StatefulWidget {
  const DebugNearbyScreen({super.key});

  @override
  State<DebugNearbyScreen> createState() => _DebugNearbyScreenState();
}

class _DebugNearbyScreenState extends State<DebugNearbyScreen> {
  Position? _currentPosition;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      // Mock position for testing (Nouakchott coordinates)
      _currentPosition = Position(
        latitude: 18.0735,
        longitude: -15.9582,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );

      dev.log(
        '[DEBUG] Using mock position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
      );
      setState(() {});
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Nearby Orders'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _initLocation),
        ],
      ),
      body: _error != null
          ? Center(child: Text('Error: $_error'))
          : _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Driver Position: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: DebugOrdersService().getNearbyOrdersUnlimited(
                      _currentPosition!,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final orders = snapshot.data ?? [];
                      dev.log('[DEBUG] UI received ${orders.length} orders');

                      if (orders.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No orders found'),
                              Text('Check console logs for details'),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final distance = order['distance'] as double;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #${order['id'].toString().substring(order['id'].toString().length - 6)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text('Status: ${order['status']}'),
                                  Text(
                                    'Distance: ${distance.toStringAsFixed(1)} km',
                                  ),
                                  Text('Price: ${order['price']} MRU'),
                                  if (order['pickup'] != null) ...[
                                    Text(
                                      'Pickup: ${order['pickup']['label'] ?? 'No label'}',
                                    ),
                                    Text(
                                      'Pickup Coords: ${order['pickup']['lat']}, ${order['pickup']['lng']}',
                                    ),
                                  ],
                                  if (order['dropoff'] != null) ...[
                                    Text(
                                      'Dropoff: ${order['dropoff']['label'] ?? 'No label'}',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
