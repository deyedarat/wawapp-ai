import 'package:flutter/material.dart';

class OrderDetailsCard extends StatelessWidget {
  const OrderDetailsCard({
    super.key,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.price,
    required this.distance,
    required this.elapsedText,
  });

  final String pickupLabel;
  final String dropoffLabel;
  final double price;
  final double distance;
  final String elapsedText;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LocationRow(
            icon: Icons.circle,
            color: const Color(0xFF4CAF50),
            label: pickupLabel,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 10),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                width: 2,
                height: 24,
                color: Colors.grey.shade300,
              ),
            ),
          ),
          _LocationRow(
            icon: Icons.location_on,
            color: const Color(0xFFE53935),
            label: dropoffLabel,
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MetricTile(
                label: 'السعر',
                value: '${price.toStringAsFixed(0)} MRU',
                color: const Color(0xFF4CAF50),
              ),
              _MetricTile(
                label: 'المسافة',
                value: '${distance.toStringAsFixed(1)} كم',
                color: const Color(0xFF1976D2),
              ),
              _MetricTile(
                label: 'منذ',
                value: elapsedText,
                color: const Color(0xFFFF9800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
