import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/cart_provider.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import '../order/checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cartProvider = context.watch<CartProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('my_cart')),
        actions: [
          if (!cartProvider.isEmpty)
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.tr('clear_cart')),
                    content: Text(l10n.tr('confirm')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(l10n.tr('cancel')),
                      ),
                      TextButton(
                        onPressed: () {
                          cartProvider.clearCart();
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          l10n.tr('delete'),
                          style: const TextStyle(color: AppTheme.error),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
              label: Text(
                l10n.tr('clear_cart'),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
        ],
      ),
      body: cartProvider.isEmpty
          ? _buildEmptyCart(context, l10n)
          : _buildCartContent(context, l10n, cartProvider, localeProvider),
    );
  }

  Widget _buildEmptyCart(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.tr('cart_empty'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tr('cart_empty_subtitle'),
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent(
    BuildContext context,
    AppLocalizations l10n,
    CartProvider cartProvider,
    LocaleProvider localeProvider,
  ) {
    return Column(
      children: [
        // Store Name
        if (cartProvider.currentStoreName != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.primaryGreen.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.storefront, size: 18, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  cartProvider.currentStoreName!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),

        // Cart Items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cartProvider.items.length,
            itemBuilder: (context, index) {
              final item = cartProvider.items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Product Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: Image.network(
                            item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              child: const Icon(
                                Icons.shopping_bag,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Product Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.getLocalizedName(localeProvider.languageCode),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.price.toStringAsFixed(0)} ${l10n.tr('mru')}',
                              style: const TextStyle(
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Quantity Controls
                      Column(
                        children: [
                          Row(
                            children: [
                              _buildQuantityButton(
                                icon: Icons.remove,
                                onPressed: () {
                                  cartProvider.decrementQuantity(item.productId);
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              _buildQuantityButton(
                                icon: Icons.add,
                                onPressed: () {
                                  cartProvider.incrementQuantity(item.productId);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.total.toStringAsFixed(0)} ${l10n.tr('mru')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom Summary & Checkout
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l10n.tr('items_count')}: ${cartProvider.itemCount}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      '${l10n.tr('total')}: ${cartProvider.totalAmount.toStringAsFixed(0)} ${l10n.tr('mru')}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CheckoutScreen(),
                        ),
                      );
                    },
                    child: Text(
                      l10n.tr('checkout'),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: AppTheme.primaryGreen),
        onPressed: onPressed,
      ),
    );
  }
}
