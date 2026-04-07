import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/products_provider.dart';
import '../../services/mock_data_service.dart';
import '../../theme/app_theme.dart';

class AddEditProductScreen extends StatefulWidget {
  final ProductModel? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameArController;
  late TextEditingController _nameFrController;
  late TextEditingController _priceController;
  late TextEditingController _imageUrlController;
  String _selectedCategory = 'fruits';
  String _selectedUnit = 'kg';
  bool _isAvailable = true;

  bool get isEditing => widget.product != null;

  final _units = [
    {'id': 'kg', 'ar': 'كغ', 'fr': 'kg'},
    {'id': 'liter', 'ar': 'لتر', 'fr': 'litre'},
    {'id': 'piece', 'ar': 'قطعة', 'fr': 'pièce'},
    {'id': 'bottle', 'ar': 'قارورة', 'fr': 'bouteille'},
    {'id': 'can', 'ar': 'علبة', 'fr': 'canette'},
    {'id': 'box', 'ar': 'علبة', 'fr': 'boîte'},
    {'id': 'pack', 'ar': 'كيس', 'fr': 'paquet'},
  ];

  @override
  void initState() {
    super.initState();
    _nameArController =
        TextEditingController(text: widget.product?.nameAr ?? '');
    _nameFrController =
        TextEditingController(text: widget.product?.nameFr ?? '');
    _priceController = TextEditingController(
        text: widget.product?.price.toStringAsFixed(0) ?? '');
    _imageUrlController =
        TextEditingController(text: widget.product?.imageUrl ?? '');

    if (isEditing) {
      _selectedCategory = widget.product!.category.isNotEmpty
          ? widget.product!.category
          : 'fruits';
      _selectedUnit =
          widget.product!.unit.isNotEmpty ? widget.product!.unit : 'kg';
      _isAvailable = widget.product!.isAvailable;
    }
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameFrController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final productsProvider = context.read<ProductsProvider>();
    final storeId = context.read<AuthProvider>().user?.storeId ?? 'store_1';
    final categories = MockDataService.getCategories();
    final category = categories.firstWhere(
      (c) => c['id'] == _selectedCategory,
      orElse: () => categories.first,
    );
    final unit = _units.firstWhere(
      (u) => u['id'] == _selectedUnit,
      orElse: () => _units.first,
    );

    final product = ProductModel(
      id: isEditing
          ? widget.product!.id
          : 'p_${DateTime.now().millisecondsSinceEpoch}',
      storeId: storeId,
      name: _nameFrController.text.trim(),
      nameAr: _nameArController.text.trim(),
      nameFr: _nameFrController.text.trim(),
      price: double.tryParse(_priceController.text) ?? 0,
      unit: _selectedUnit,
      unitAr: unit['ar'] ?? '',
      unitFr: unit['fr'] ?? '',
      imageUrl: _imageUrlController.text.trim().isNotEmpty
          ? _imageUrlController.text.trim()
          : 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=300',
      category: _selectedCategory,
      categoryAr: category['ar'] ?? '',
      categoryFr: category['fr'] ?? '',
      isAvailable: _isAvailable,
      createdAt: DateTime.now(),
    );

    if (isEditing) {
      await productsProvider.updateProduct(product);
    } else {
      await productsProvider.addProduct(product);
    }

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? l10n.tr('product_updated') : l10n.tr('product_added'),
          ),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = context.watch<LocaleProvider>();
    final categories = MockDataService.getCategories();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.tr('edit_product') : l10n.tr('add_product')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Preview
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: AppTheme.offWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.lightGrey),
                ),
                child: _imageUrlController.text.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _imageUrlController.text,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildImagePlaceholder(l10n),
                        ),
                      )
                    : _buildImagePlaceholder(l10n),
              ),

              const SizedBox(height: 16),

              // Image URL
              TextFormField(
                controller: _imageUrlController,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.tr('product_image'),
                  prefixIcon: const Icon(Icons.image_outlined),
                  hintText: 'https://...',
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),

              // Name Arabic
              TextFormField(
                controller: _nameArController,
                decoration: InputDecoration(
                  labelText: '${l10n.tr('product_name')} (${l10n.tr('arabic')})',
                  prefixIcon: const Icon(Icons.text_fields),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.tr('product_name');
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Name French
              TextFormField(
                controller: _nameFrController,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: '${l10n.tr('product_name')} (${l10n.tr('french')})',
                  prefixIcon: const Icon(Icons.text_fields),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.tr('product_name');
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Price
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: '${l10n.tr('product_price')} (${l10n.tr('mru')})',
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.tr('product_price');
                  }
                  if (double.tryParse(value) == null) {
                    return l10n.tr('product_price');
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: l10n.tr('product_category'),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: categories.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat['id'],
                    child: Text(
                      localeProvider.isArabic
                          ? (cat['ar'] ?? '')
                          : (cat['fr'] ?? ''),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedCategory = value ?? 'fruits');
                },
              ),

              const SizedBox(height: 16),

              // Unit Dropdown
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: InputDecoration(
                  labelText: l10n.tr('product_unit'),
                  prefixIcon: const Icon(Icons.straighten),
                ),
                items: _units.map((unit) {
                  return DropdownMenuItem<String>(
                    value: unit['id'],
                    child: Text(
                      localeProvider.isArabic
                          ? (unit['ar'] ?? '')
                          : (unit['fr'] ?? ''),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedUnit = value ?? 'kg');
                },
              ),

              const SizedBox(height: 16),

              // Availability Switch
              Card(
                child: SwitchListTile(
                  title: Text(l10n.tr('available')),
                  subtitle: Text(
                    _isAvailable
                        ? l10n.tr('available')
                        : l10n.tr('unavailable'),
                    style: TextStyle(
                      color: _isAvailable ? AppTheme.success : AppTheme.error,
                    ),
                  ),
                  value: _isAvailable,
                  onChanged: (value) {
                    setState(() => _isAvailable = value);
                  },
                  activeColor: AppTheme.primaryGreen,
                  secondary: Icon(
                    _isAvailable ? Icons.check_circle : Icons.cancel,
                    color: _isAvailable ? AppTheme.success : AppTheme.error,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saveProduct,
                  icon: Icon(isEditing ? Icons.save : Icons.add),
                  label: Text(
                    isEditing ? l10n.tr('save') : l10n.tr('add_product'),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            l10n.tr('product_image'),
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
