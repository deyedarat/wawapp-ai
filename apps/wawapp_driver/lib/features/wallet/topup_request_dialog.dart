/// Topup Request Dialog
///
/// Dialog for requesting wallet top-up with amount validation
///
/// Author: WawApp Development Team
/// Last Updated: 2025-12-30

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/colors.dart';

/// Constants matching backend validation
const int kMinTopupAmount = 1000; // 1,000 MRU minimum
const int kMaxTopupAmount = 100000; // 100,000 MRU maximum

/// Shows a dialog to request wallet top-up
///
/// Returns the amount if user confirms, null if cancelled
Future<double?> showTopupRequestDialog(BuildContext context) async {
  return showDialog<double>(
    context: context,
    builder: (context) => const TopupRequestDialog(),
  );
}

class TopupRequestDialog extends StatefulWidget {
  const TopupRequestDialog({super.key});

  @override
  State<TopupRequestDialog> createState() => _TopupRequestDialogState();
}

class _TopupRequestDialogState extends State<TopupRequestDialog> {
  final TextEditingController _amountController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _errorText;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال المبلغ';
    }

    final amount = double.tryParse(value);
    if (amount == null) {
      return 'المبلغ غير صحيح';
    }

    if (amount < kMinTopupAmount) {
      return 'الحد الأدنى هو $kMinTopupAmount MRU';
    }

    if (amount > kMaxTopupAmount) {
      return 'الحد الأقصى هو $kMaxTopupAmount MRU';
    }

    return null;
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final amount = double.parse(_amountController.text);
      Navigator.of(context).pop(amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: DriverAppColors.primaryLight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              color: DriverAppColors.primaryLight,
            ),
          ),
          const SizedBox(width: 12),
          const Text('طلب شحن رصيد'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'أدخل المبلغ الذي تريد شحنه في محفظتك',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: DriverAppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: 'المبلغ (MRU)',
                prefixIcon: const Icon(Icons.attach_money),
                hintText: 'مثال: 5000',
                helperText:
                    'الحد الأدنى: $kMinTopupAmount MRU\nالحد الأقصى: $kMaxTopupAmount MRU',
                helperMaxLines: 2,
                errorText: _errorText,
              ),
              validator: _validateAmount,
              onChanged: (value) {
                if (_errorText != null) {
                  setState(() {
                    _errorText = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DriverAppColors.infoLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: DriverAppColors.infoLight.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: DriverAppColors.infoLight,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سيتم مراجعة طلبك من قبل الإدارة',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: DriverAppColors.infoLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: DriverAppColors.primaryLight,
            foregroundColor: Colors.white,
          ),
          child: const Text('إرسال الطلب'),
        ),
      ],
    );
  }
}
