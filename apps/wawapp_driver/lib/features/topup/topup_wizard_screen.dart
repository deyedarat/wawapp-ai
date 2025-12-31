import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/topup_provider.dart';

/// Main wizard screen for top-up flow
class TopupWizardScreen extends ConsumerWidget {
  const TopupWizardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = ref.watch(topupWizardStepProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('شحن المحفظة'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (currentStep > 0) {
              ref.read(topupWizardStepProvider.notifier).state =
                  currentStep - 1;
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (currentStep + 1) / 3,
          ),
          Expanded(
            child: IndexedStack(
              index: currentStep,
              children: const [
                Step1BankSelectionScreen(),
                Step2DestinationCodeScreen(),
                Step3AmountScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 1: Bank App Selection
class Step1BankSelectionScreen extends ConsumerWidget {
  const Step1BankSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bankAppsAsync = ref.watch(bankAppsProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اختر تطبيق البنك',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'اختر التطبيق الذي ستستخدمه للشحن',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: bankAppsAsync.when(
              data: (bankApps) {
                if (bankApps.isEmpty) {
                  return const Center(
                    child: Text('لا توجد تطبيقات بنكية متاحة حالياً'),
                  );
                }

                return ListView.builder(
                  itemCount: bankApps.length,
                  itemBuilder: (context, index) {
                    final bankApp = bankApps[index];
                    final isSelected =
                        ref.watch(selectedBankAppProvider)?.id == bankApp.id;

                    return Card(
                      elevation: isSelected ? 4 : 1,
                      color: isSelected ? Colors.blue.shade50 : null,
                      child: ListTile(
                        leading: bankApp.logoUrl != null
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(bankApp.logoUrl!),
                              )
                            : const CircleAvatar(
                                child: Icon(Icons.account_balance),
                              ),
                        title: Text(
                          bankApp.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.blue)
                            : null,
                        onTap: () {
                          ref.read(selectedBankAppProvider.notifier).state =
                              bankApp;
                          ref.read(topupWizardStepProvider.notifier).state = 1;
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('خطأ في تحميل التطبيقات: $error'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 2: Destination Code Display
class Step2DestinationCodeScreen extends ConsumerWidget {
  const Step2DestinationCodeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBank = ref.watch(selectedBankAppProvider);

    if (selectedBank == null) {
      return const Center(child: Text('لم يتم اختيار بنك'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'رمز الوجهة',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'استخدم هذا الرمز في تطبيق ${selectedBank.name}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'رمز الوجهة',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    selectedBank.destinationCode,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: selectedBank.destinationCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ الرمز')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('نسخ الرمز'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'التعليمات',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('1. افتح تطبيق ${selectedBank.name}'),
                  const SizedBox(height: 8),
                  const Text('2. اختر خيار التحويل'),
                  const SizedBox(height: 8),
                  const Text('3. أدخل رمز الوجهة أعلاه'),
                  const SizedBox(height: 8),
                  const Text('4. أدخل المبلغ الذي تريد شحنه'),
                  const SizedBox(height: 8),
                  const Text('5. أكمل العملية في التطبيق'),
                ],
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              ref.read(topupWizardStepProvider.notifier).state = 2;
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
            child: const Text('التالي - تأكيد المبلغ'),
          ),
        ],
      ),
    );
  }
}

/// Step 3: Amount Confirmation
class Step3AmountScreen extends ConsumerStatefulWidget {
  const Step3AmountScreen({super.key});

  @override
  ConsumerState<Step3AmountScreen> createState() => _Step3AmountScreenState();
}

class _Step3AmountScreenState extends ConsumerState<Step3AmountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedBank = ref.watch(selectedBankAppProvider);

    if (selectedBank == null) {
      return const Center(child: Text('لم يتم اختيار بنك'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'تأكيد المبلغ',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'أدخل المبلغ الذي قمت بتحويله',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ (MRU)',
                hintText: '5000',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'المبلغ مطلوب';
                }
                final amount = int.tryParse(value);
                if (amount == null) {
                  return 'أدخل رقماً صحيحاً';
                }
                if (amount < 1000) {
                  return 'الحد الأدنى 1,000 MRU';
                }
                if (amount > 100000) {
                  return 'الحد الأقصى 100,000 MRU';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف المرسل (اختياري)',
                hintText: '+22236123456',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              color: Colors.orange.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'سيتم مراجعة الطلب من قبل الإدارة وإضافة المبلغ إلى محفظتك',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('إرسال الطلب'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(topupServiceProvider);
      final selectedBank = ref.read(selectedBankAppProvider)!;
      final user = ref.read(authStreamProvider).value;

      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final amount = int.parse(_amountController.text);
      final phone =
          _phoneController.text.isEmpty ? null : _phoneController.text;

      await service.createTopupRequest(
        userId: user.uid,
        bankAppId: selectedBank.id,
        bankAppName: selectedBank.name,
        destinationCode: selectedBank.destinationCode,
        amount: amount,
        senderPhone: phone,
      );

      if (!mounted) return;

      // Reset wizard
      ref.read(topupWizardStepProvider.notifier).state = 0;
      ref.read(selectedBankAppProvider.notifier).state = null;
      ref.read(topupAmountProvider.notifier).state = null;
      ref.read(senderPhoneProvider.notifier).state = null;

      // Show success and go back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الطلب بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

// Temporary auth provider - needs to be replaced with actual auth provider
final authStreamProvider = StreamProvider<User?>((ref) {
  return Stream.value(null);
});

class User {
  final String uid;
  User(this.uid);
}
