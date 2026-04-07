import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/orders_provider.dart';
import '../../theme/app_theme.dart';
import '../tracking/order_tracking_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  DeliveryType _deliveryType = DeliveryType.delivery;
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _addressController.text = user?.address ?? '';
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_deliveryType == DeliveryType.delivery &&
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).tr('delivery_address')),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isPlacingOrder = true);

    final cartProvider = context.read<CartProvider>();
    final authProvider = context.read<AuthProvider>();
    final ordersProvider = context.read<OrdersProvider>();

    final order = await ordersProvider.placeOrder(
      userId: authProvider.user?.id ?? 'guest',
      userName: authProvider.user?.name ?? 'زائر',
      userPhone: authProvider.user?.phone ?? '',
      storeId: cartProvider.currentStoreId ?? '',
      storeName: cartProvider.currentStoreName ?? '',
      items: List.from(cartProvider.items),
      totalAmount: cartProvider.totalAmount,
      deliveryType: _deliveryType,
      deliveryAddress: _addressController.text.trim(),
      notes: _notesController.text.trim(),
    );

    cartProvider.clearCart();

    if (mounted) {
      setState(() => _isPlacingOrder = false);
      _showOrderConfirmation(order);
    }
  }

  void _showOrderConfirmation(OrderModel order) {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: AppTheme.success,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.tr('order_placed'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tr('order_placed_subtitle'),
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.offWhite,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${l10n.tr('order_id')}: ${order.id}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textDirection: TextDirection.ltr,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderTrackingScreen(order: order),
                  ),
                );
              },
              child: Text(l10n.tr('order_tracking')),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text(l10n.tr('home')),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cartProvider = context.watch<CartProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('order_confirmation')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('order_summary'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    ...cartProvider.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.getLocalizedName(localeProvider.languageCode)} x${item.quantity}',
                                ),
                              ),
                              Text(
                                '${item.total.toStringAsFixed(0)} ${l10n.tr('mru')}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.tr('total'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${cartProvider.totalAmount.toStringAsFixed(0)} ${l10n.tr('mru')}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Delivery Method
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('delivery_method'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<DeliveryType>(
                      value: DeliveryType.delivery,
                      groupValue: _deliveryType,
                      onChanged: (value) {
                        setState(() => _deliveryType = value!);
                      },
                      title: Text(l10n.tr('delivery')),
                      subtitle: Text(l10n.tr('delivery_address')),
                      secondary: const Icon(Icons.delivery_dining,
                          color: AppTheme.primaryGreen),
                      activeColor: AppTheme.primaryGreen,
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<DeliveryType>(
                      value: DeliveryType.pickup,
                      groupValue: _deliveryType,
                      onChanged: (value) {
                        setState(() => _deliveryType = value!);
                      },
                      title: Text(l10n.tr('pickup')),
                      secondary: const Icon(Icons.store,
                          color: AppTheme.primaryGreen),
                      activeColor: AppTheme.primaryGreen,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Delivery Address (if delivery)
            if (_deliveryType == DeliveryType.delivery)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tr('delivery_address'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: l10n.tr('delivery_address'),
                          prefixIcon: const Icon(Icons.location_on_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Notes
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('order_notes'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: l10n.tr('order_notes_hint'),
                        prefixIcon: const Icon(Icons.note_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Payment Method
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('payment_method'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.money, color: AppTheme.primaryGreen),
                      title: Text(l10n.tr('cash_on_delivery')),
                      trailing: const Icon(Icons.check_circle, color: AppTheme.primaryGreen),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Place Order Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isPlacingOrder ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: _isPlacingOrder
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        '${l10n.tr('place_order')} - ${cartProvider.totalAmount.toStringAsFixed(0)} ${l10n.tr('mru')}',
                      ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
