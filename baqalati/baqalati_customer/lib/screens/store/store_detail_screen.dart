import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/store_model.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/mock_data_service.dart';
import '../../theme/app_theme.dart';
import '../cart/cart_screen.dart';

class StoreDetailScreen extends StatefulWidget {
  final StoreModel store;

  const StoreDetailScreen({super.key, required this.store});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = context.watch<LocaleProvider>();
    final cartProvider = context.watch<CartProvider>();
    final products = MockDataService.getMockProducts(widget.store.id);

    // Get unique categories
    final categories = products
        .map((p) => localeProvider.isArabic ? p.categoryAr : p.categoryFr)
        .toSet()
        .toList();

    // Filter products by category
    final filteredProducts = _selectedCategory == null
        ? products
        : products.where((p) {
            final cat = localeProvider.isArabic ? p.categoryAr : p.categoryFr;
            return cat == _selectedCategory;
          }).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Store Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.store.getLocalizedName(localeProvider.languageCode),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.store.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.primaryGreen,
                      child: const Icon(Icons.storefront, size: 80, color: Colors.white54),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (cartProvider.itemCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8),
                  child: IconButton(
                    icon: Badge(
                      label: Text('${cartProvider.itemCount}'),
                      child: const Icon(Icons.shopping_cart),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CartScreen()),
                      );
                    },
                  ),
                ),
            ],
          ),

          // Store Info
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating & Status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.store.isOpen
                              ? AppTheme.success.withOpacity(0.1)
                              : AppTheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: widget.store.isOpen ? AppTheme.success : AppTheme.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.store.isOpen ? l10n.tr('open_now') : l10n.tr('closed'),
                              style: TextStyle(
                                color: widget.store.isOpen ? AppTheme.success : AppTheme.error,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        widget.store.rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${widget.store.totalOrders})',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Address
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.store.getLocalizedAddress(localeProvider.languageCode),
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Phone
                  Row(
                    children: [
                      Icon(Icons.phone, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        widget.store.phone,
                        style: TextStyle(color: Colors.grey[700]),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Delivery Info
                  Row(
                    children: [
                      Icon(Icons.delivery_dining, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          localeProvider.isArabic
                              ? widget.store.deliveryInfoAr
                              : widget.store.deliveryInfoFr,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 24),

                  // Products Header
                  Text(
                    l10n.tr('products'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Category Filter Chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(l10n.tr('all')),
                      selected: _selectedCategory == null,
                      onSelected: (_) {
                        setState(() => _selectedCategory = null);
                      },
                      selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                      checkmarkColor: AppTheme.primaryGreen,
                    ),
                  ),
                  ...categories.map((cat) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(cat),
                          selected: _selectedCategory == cat,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory =
                                  _selectedCategory == cat ? null : cat;
                            });
                          },
                          selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                          checkmarkColor: AppTheme.primaryGreen,
                        ),
                      )),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Products Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = filteredProducts[index];
                  return _buildProductCard(
                    context, product, l10n, localeProvider, cartProvider,
                  );
                },
                childCount: filteredProducts.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),

      // Floating Cart Button
      floatingActionButton: cartProvider.itemCount > 0 &&
              cartProvider.currentStoreId == widget.store.id
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
              icon: const Icon(Icons.shopping_cart),
              label: Text(
                '${l10n.tr('cart')} (${cartProvider.itemCount}) - ${cartProvider.totalAmount.toStringAsFixed(0)} ${l10n.tr('mru')}',
              ),
            )
          : null,
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    ProductModel product,
    AppLocalizations l10n,
    LocaleProvider localeProvider,
    CartProvider cartProvider,
  ) {
    final isInCart = cartProvider.items
        .any((item) => item.productId == product.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    child: const Icon(
                      Icons.shopping_bag,
                      size: 40,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
                if (!product.isAvailable)
                  Container(
                    color: Colors.black45,
                    child: Center(
                      child: Text(
                        l10n.tr('unavailable'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Product Info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product.getLocalizedName(localeProvider.languageCode),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${product.price.toStringAsFixed(0)} ${l10n.tr('mru')}/${product.getLocalizedUnit(localeProvider.languageCode)}',
                          style: const TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            isInCart ? Icons.check_circle : Icons.add_circle,
                            color: isInCart ? AppTheme.success : AppTheme.primaryGreen,
                            size: 28,
                          ),
                          onPressed: product.isAvailable
                              ? () {
                                  cartProvider.addProduct(
                                    product,
                                    storeName: widget.store.getLocalizedName(
                                        localeProvider.languageCode),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.tr('added_to_cart')),
                                      duration: const Duration(seconds: 1),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
