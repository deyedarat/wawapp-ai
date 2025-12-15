import 'package:flutter/material.dart';

/// Phase 2: Reusable UI components for stuck state recovery
/// These widgets surface stuck/timeout states to users per spec Section 2

/// Banner for order stuck in pending (10 min threshold)
class OrderStuckPendingBanner extends StatelessWidget {
  final String orderId;
  final VoidCallback onCancel;

  const OrderStuckPendingBanner({
    super.key,
    required this.orderId,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange.shade100,
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No drivers available',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your order has been pending for over 10 minutes. You can wait longer or cancel.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onCancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Modal for order stuck in accepting (2 min threshold)
class OrderStuckAcceptingDialog extends StatelessWidget {
  final String orderId;
  final String driverId;

  const OrderStuckAcceptingDialog({
    super.key,
    required this.orderId,
    required this.driverId,
  });

  static Future<void> show(BuildContext context, String orderId, String driverId) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => OrderStuckAcceptingDialog(orderId: orderId, driverId: driverId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.error_outline, color: Colors.orange, size: 48),
      title: const Text('Driver Did Not Confirm'),
      content: const Text(
        'The driver did not confirm the order within the expected time. '
        'We are searching for another driver for you.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Error widget for action timeout (15 sec threshold)
class ActionTimeoutError extends StatelessWidget {
  final String actionName;
  final VoidCallback onRetry;

  const ActionTimeoutError({
    super.key,
    required this.actionName,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_off, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Request Timed Out',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'The request took too long to complete. Please try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Snackbar for driver toggle timeout (5 sec threshold)
class DriverToggleTimeoutSnackbar {
  static void show(BuildContext context, bool targetOnlineState) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Failed to update status to ${targetOnlineState ? "online" : "offline"}. Please retry.',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            // Retry handled by caller
          },
        ),
      ),
    );
  }
}

/// Error widget for payment timeout (30 sec threshold)
class PaymentTimeoutError extends StatelessWidget {
  final String orderId;
  final VoidCallback onContactSupport;

  const PaymentTimeoutError({
    super.key,
    required this.orderId,
    required this.onContactSupport,
  });

  static Future<void> show(BuildContext context, String orderId, VoidCallback onContactSupport) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentTimeoutError(
        orderId: orderId,
        onContactSupport: onContactSupport,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.warning_amber, color: Colors.red, size: 48),
      title: const Text('Payment Confirmation Delayed'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The payment processing is taking longer than expected.',
          ),
          const SizedBox(height: 16),
          Text(
            'Order ID: $orderId',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Wait'),
        ),
        ElevatedButton.icon(
          onPressed: onContactSupport,
          icon: const Icon(Icons.support_agent),
          label: const Text('Contact Support'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Banner for Firestore listener disconnected (60 sec threshold)
class ConnectionLostBanner extends StatelessWidget {
  final bool isRetrying;

  const ConnectionLostBanner({
    super.key,
    this.isRetrying = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.red.shade100,
      child: Row(
        children: [
          if (isRetrying)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.cloud_off, color: Colors.red),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Connection lost, retrying...',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic network error banner
class NetworkErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const NetworkErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.red.shade50,
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
