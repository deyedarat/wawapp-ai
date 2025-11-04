import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneInputField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final String? errorText;
  final VoidCallback? onChanged;
  final bool enabled;

  const PhoneInputField({
    super.key,
    required this.controller,
    this.hintText,
    this.errorText,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[+\d]')),
        LengthLimitingTextInputFormatter(15),
      ],
      decoration: InputDecoration(
        hintText: hintText ?? '+22212345678',
        errorText: errorText,
        prefixIcon: const Icon(Icons.phone),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      onChanged: (_) => onChanged?.call(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Phone number is required';
        }
        if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(value)) {
          return 'Enter a valid phone number with country code';
        }
        return null;
      },
    );
  }
}