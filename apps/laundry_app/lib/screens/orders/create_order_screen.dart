import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/customers_provider.dart';

/// Screen for creating a new laundry order.
class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _discountController = TextEditingController();

  UserModel? _selectedCustomer;
  final List<OrderItemModel> _items = [];
  DateTime _estimatedCompletion = DateTime.now().add(const Duration(hours: 24));
  bool _isSubmitting = false;

  double get _totalPrice =>
      _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get _discount => double.tryParse(_discountController.text) ?? 0;

  double get _finalPrice => _totalPrice - _discount;

  @override
  void dispose() {
    _phoneController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب جديد'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Customer Selection
            _buildCustomerSection(),
            const SizedBox(height: 24),

            // Items Section
            _buildItemsSection(),
            const SizedBox(height: 24),

            // Estimated Time
            _buildEstimatedTimeSection(),
            const SizedBox(height: 24),

            // Notes & Discount
            _buildNotesSection(),
            const SizedBox(height: 24),

            // Price Summary
            _buildPriceSummary(),
            const SizedBox(height: 24),

            // Submit Button
            _buildSubmitButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person, color: Color(0xFF1B5E20)),
                SizedBox(width: 8),
                Text(
                  'اختر الزبون',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedCustomer != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      child: Icon(Icons.person),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCustomer!.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            Formatters.formatPhoneDisplay(
                                _selectedCustomer!.phoneNumber),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() => _selectedCustomer = null);
                      },
                    ),
                  ],
                ),
              ),
            ] else ...[
              PhoneInputField(
                controller: _phoneController,
                hintText: 'ابحث برقم الهاتف',
                onChanged: (value) {
                  if (value.length >= 3) {
                    context.read<CustomersProvider>().searchByPhone(value);
                  }
                },
              ),
              const SizedBox(height: 8),
              Consumer<CustomersProvider>(
                builder: (context, customersProvider, _) {
                  if (customersProvider.isSearching) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (customersProvider.searchResults.isEmpty &&
                      _phoneController.text.length >= 3) {
                    return Column(
                      children: [
                        Text(
                          'لم يتم العثور على زبون',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        TextButton.icon(
                          onPressed: _showAddCustomerDialog,
                          icon: const Icon(Icons.person_add),
                          label: const Text('إضافة زبون جديد'),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: customersProvider.searchResults.map((customer) {
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(customer.name),
                        subtitle: Text(
                          Formatters.formatPhoneDisplay(customer.phoneNumber),
                          textDirection: TextDirection.ltr,
                        ),
                        onTap: () {
                          setState(() => _selectedCustomer = customer);
                          customersProvider.clearSearch();
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.checkroom, color: Color(0xFF1B5E20)),
                    SizedBox(width: 8),
                    Text(
                      'القطع',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _showAddItemDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'أضف القطع المراد غسلها',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.type.arabicName),
                    subtitle: Text(
                      '${item.quantity} × ${Formatters.formatPrice(item.pricePerItem)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Formatters.formatPrice(item.totalPrice),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () {
                            setState(() => _items.removeAt(index));
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimatedTimeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.schedule, color: Color(0xFF1B5E20)),
                SizedBox(width: 8),
                Text(
                  'الموعد المتوقع',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectDateTime,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      Formatters.formatDateTime(_estimatedCompletion),
                      style: const TextStyle(fontSize: 15),
                    ),
                    const Spacer(),
                    const Icon(Icons.edit, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Quick time buttons
            Wrap(
              spacing: 8,
              children: [
                _QuickTimeChip(
                  label: '6 ساعات',
                  onTap: () => setState(() {
                    _estimatedCompletion =
                        DateTime.now().add(const Duration(hours: 6));
                  }),
                ),
                _QuickTimeChip(
                  label: '12 ساعة',
                  onTap: () => setState(() {
                    _estimatedCompletion =
                        DateTime.now().add(const Duration(hours: 12));
                  }),
                ),
                _QuickTimeChip(
                  label: '24 ساعة',
                  onTap: () => setState(() {
                    _estimatedCompletion =
                        DateTime.now().add(const Duration(hours: 24));
                  }),
                ),
                _QuickTimeChip(
                  label: '48 ساعة',
                  onTap: () => setState(() {
                    _estimatedCompletion =
                        DateTime.now().add(const Duration(hours: 48));
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                hintText: 'مثال: غسيل جاف فقط للجاكيت',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _discountController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'خصم (اختياري)',
                hintText: '0',
                suffixText: 'أوقية',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSummary() {
    return Card(
      color: const Color(0xFF1B5E20).withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المجموع'),
                Text(Formatters.formatPrice(_totalPrice)),
              ],
            ),
            if (_discount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الخصم'),
                  Text(
                    '- ${Formatters.formatPrice(_discount)}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'الإجمالي',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  Formatters.formatPrice(_finalPrice),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isValid = _selectedCustomer != null && _items.isNotEmpty;

    return ElevatedButton(
      onPressed: isValid && !_isSubmitting ? _submitOrder : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isSubmitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Text(
              'إنشاء الطلب',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    );
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _estimatedCompletion,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_estimatedCompletion),
    );
    if (time == null) return;

    setState(() {
      _estimatedCompletion = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _showAddItemDialog() {
    LaundryItemType selectedType = LaundryItemType.shirt;
    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('إضافة قطعة'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<LaundryItemType>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'نوع القطعة',
                      ),
                      items: LaundryItemType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.arabicName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedType = value!);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الكمية',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'السعر للقطعة (أوقية)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final quantity =
                        int.tryParse(quantityController.text) ?? 0;
                    final price =
                        double.tryParse(priceController.text) ?? 0;

                    if (quantity > 0 && price > 0) {
                      setState(() {
                        _items.add(OrderItemModel(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          type: selectedType,
                          quantity: quantity,
                          pricePerItem: price,
                        ));
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('إضافة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddCustomerDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة زبون جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الزبون',
                  hintText: 'أدخل اسم الزبون',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final customer =
                      await context.read<CustomersProvider>().createCustomer(
                            name: name,
                            phoneNumber: _phoneController.text,
                          );
                  if (customer != null && mounted) {
                    setState(() => _selectedCustomer = customer);
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitOrder() async {
    if (_selectedCustomer == null || _items.isEmpty) return;

    setState(() => _isSubmitting = true);

    final authProvider = context.read<LaundryAuthProvider>();
    final ordersProvider = context.read<OrdersProvider>();

    final orderId = await ordersProvider.createOrder(
      customerId: _selectedCustomer!.uid,
      customerName: _selectedCustomer!.name,
      customerPhone: _selectedCustomer!.phoneNumber,
      laundryId: authProvider.currentUser!.uid,
      items: _items,
      totalPrice: _totalPrice,
      estimatedCompletionTime: _estimatedCompletion,
      staffId: authProvider.currentUser!.uid,
      discount: _discount > 0 ? _discount : null,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );

    setState(() => _isSubmitting = false);

    if (orderId != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء الطلب بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ordersProvider.errorMessage ?? 'حدث خطأ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _QuickTimeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickTimeChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
    );
  }
}
