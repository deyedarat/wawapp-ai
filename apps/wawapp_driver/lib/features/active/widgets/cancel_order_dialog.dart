import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

/// Shows a dialog for the driver to select a cancellation reason.
/// Returns the selected [CancelReason] or null if dismissed.
Future<CancelReason?> showCancelOrderDialog(BuildContext context) {
  return showDialog<CancelReason>(
    context: context,
    builder: (_) => const _CancelOrderDialog(),
  );
}

class _CancelOrderDialog extends StatefulWidget {
  const _CancelOrderDialog();

  @override
  State<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<_CancelOrderDialog> {
  CancelReason? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إلغاء الطلب'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('اختر سبب الإلغاء:'),
          const SizedBox(height: 8),
          for (final reason in CancelReason.values)
            RadioListTile<CancelReason>(
              title: Text(reason.arabicLabel),
              value: reason,
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v),
              dense: true,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('رجوع'),
        ),
        TextButton(
          onPressed: _selected != null
              ? () => Navigator.of(context).pop(_selected)
              : null,
          style:
              TextButton.styleFrom(foregroundColor: DriverAppColors.accentRed),
          child: const Text('تأكيد الإلغاء'),
        ),
      ],
    );
  }
}
