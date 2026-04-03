import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/orders_service.dart';

/// Shows a full-screen new order alert dialog.
/// Returns when the dialog is dismissed (accept, decline, or snooze).
Future<void> showNewOrderAlertDialog(
  BuildContext context, {
  required String orderId,
  required String pickupLabel,
  required String dropoffLabel,
  required double price,
  required double distance,
  VoidCallback? onSnooze,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => _NewOrderAlertDialog(
      orderId: orderId,
      pickupLabel: pickupLabel,
      dropoffLabel: dropoffLabel,
      price: price,
      distance: distance,
      onSnooze: onSnooze,
    ),
  );
}

class _NewOrderAlertDialog extends ConsumerStatefulWidget {
  const _NewOrderAlertDialog({
    required this.orderId,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.price,
    required this.distance,
    this.onSnooze,
  });

  final String orderId;
  final String pickupLabel;
  final String dropoffLabel;
  final double price;
  final double distance;
  final VoidCallback? onSnooze;

  @override
  ConsumerState<_NewOrderAlertDialog> createState() =>
      _NewOrderAlertDialogState();
}

class _NewOrderAlertDialogState extends ConsumerState<_NewOrderAlertDialog> {
  bool _isLoading = false;

  Future<void> _acceptOrder() async {
    setState(() => _isLoading = true);
    try {
      final ordersService = ref.read(ordersServiceProvider);
      await ordersService.acceptOrder(widget.orderId);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/active-order');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خطأ: ${e.toString().contains('already taken') ? 'تم أخذ الطلب بالفعل' : e.toString()}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async => false,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_shipping, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  'طلب جديد قريب منك',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetailRow(
                  Icons.location_on,
                  Colors.green,
                  widget.pickupLabel,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.flag,
                  Colors.red,
                  widget.dropoffLabel,
                ),
                const SizedBox(height: 8),
                Text(
                  'السعر: ${widget.price} MRU',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'المسافة: ${widget.distance} كم',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        color: Colors.green,
                        icon: Icons.check,
                        label: 'قبول',
                        onPressed: _acceptOrder,
                      ),
                      _buildActionButton(
                        color: Colors.red,
                        icon: Icons.close,
                        label: 'رفض',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      _buildActionButton(
                        color: Colors.orange,
                        icon: Icons.schedule,
                        label: 'لاحقاً',
                        onPressed: () {
                          widget.onSnooze?.call();
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 40),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
