import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/products_provider.dart';
import '../../theme/app_theme.dart';
import 'add_edit_product_screen.dart';

class ProductsManagementScreen extends StatelessWidget {
  const ProductsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = context.watch<LocaleProvider>();
    final productsProvider = context.watch<ProductsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('manage_products')),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Chip(
              label: Text(
                '${productsProvider.totalProducts} ${l10n.tr('products')}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              backgroundColor: AppTheme.primaryGreenDark,
            ),
          ),
        ],
      ),
      body: productsProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : productsProvider.products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        l10n.tr('no_data'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _navigateToAddProduct(context),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.tr('add_product')),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: productsProvider.products.length,
                  itemBuilder: (context, index) {
                    final product = productsProvider.products[index];
                    return _buildProductCard(
                      context,
                      product,
                      l10n,
                      localeProvider,
                      productsProvider,
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddProduct(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.tr('add_product')),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    ProductModel product,
    AppLocalizations l10n,
    LocaleProvider localeProvider,
    ProductsProvider productsProvider,
  ) {
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
                width: 70,
                height: 70,
                child: Image.network(
                  product.imageUrl,
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
                    product.getLocalizedName(localeProvider.languageCode),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.getLocalizedCategory(localeProvider.languageCode),
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(0)} ${l10n.tr('mru')}/${product.getLocalizedUnit(localeProvider.languageCode)}',
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: product.isAvailable
                              ? AppTheme.success.withOpacity(0.1)
                              : AppTheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.isAvailable
                              ? l10n.tr('available')
                              : l10n.tr('unavailable'),
                          style: TextStyle(
                            color: product.isAvailable
                                ? AppTheme.success
                                : AppTheme.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            Column(
              children: [
                // Toggle Availability
                IconButton(
                  icon: Icon(
                    product.isAvailable
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: product.isAvailable
                        ? AppTheme.success
                        : AppTheme.grey,
                    size: 22,
                  ),
                  onPressed: () {
                    productsProvider.toggleAvailability(product.id);
                  },
                  tooltip: product.isAvailable
                      ? l10n.tr('unavailable')
                      : l10n.tr('available'),
                ),
                // Edit
                IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.info, size: 22),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddEditProductScreen(product: product),
                      ),
                    );
                  },
                  tooltip: l10n.tr('edit'),
                ),
                // Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.error, size: 22),
                  onPressed: () {
                    _confirmDelete(
                        context, product, l10n, productsProvider);
                  },
                  tooltip: l10n.tr('delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    ProductModel product,
    AppLocalizations l10n,
    ProductsProvider productsProvider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tr('delete_product')),
        content: Text(l10n.tr('confirm_delete')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.tr('cancel')),
          ),
          TextButton(
            onPressed: () {
              productsProvider.deleteProduct(product.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.tr('product_deleted')),
                  backgroundColor: AppTheme.error,
                ),
              );
            },
            child: Text(
              l10n.tr('delete'),
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddProduct(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddEditProductScreen(),
      ),
    );
  }
}
