import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Test Lab home screen for Firebase Test Lab Robo tests
/// This screen bypasses normal auth flow when TEST_LAB=true
class TestLabHome extends StatelessWidget {
  const TestLabHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TEST LAB MODE'),
        backgroundColor: Colors.orange,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.science,
              size: 64,
              color: Colors.orange,
            ),
            SizedBox(height: 16),
            Text(
              'Firebase Test Lab Mode Active',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'This screen bypasses normal authentication',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 32),
            _TestLabActionsList(),
          ],
        ),
      ),
    );
  }
}

class _TestLabActionsList extends StatelessWidget {
  const _TestLabActionsList();

  static const List<Map<String, String>> _routes = [
    {'path': '/nearby', 'title': 'Nearby Orders', 'icon': 'map'},
    {'path': '/profile', 'title': 'Driver Profile', 'icon': 'person'},
    {'path': '/wallet', 'title': 'Wallet', 'icon': 'wallet'},
    {'path': '/earnings', 'title': 'Earnings', 'icon': 'money'},
    {'path': '/history', 'title': 'Order History', 'icon': 'history'},
    {'path': '/active-order', 'title': 'Active Order', 'icon': 'delivery'},
  ];

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'map': return Icons.map;
      case 'person': return Icons.person;
      case 'wallet': return Icons.account_balance_wallet;
      case 'money': return Icons.monetization_on;
      case 'history': return Icons.history;
      case 'delivery': return Icons.delivery_dining;
      default: return Icons.touch_app;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _routes.map((route) => ListTile(
        leading: Icon(_getIcon(route['icon']!)),
        title: Text(route['title']!),
        subtitle: Text('Navigate to ${route['path']}'),
        onTap: () {
          try {
            context.go(route['path']!);
          } on Exception {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Navigation failed: ${route['path']}')),
            );
          }
        },
      )).toList(),
    );
  }
}