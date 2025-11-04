import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinInputField extends StatefulWidget {
  final Function(String) onCompleted;
  final Function(String)? onChanged;
  final bool obscureText;
  final String? errorText;
  final bool enabled;

  const PinInputField({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.obscureText = true,
    this.errorText,
    this.enabled = true,
  });

  @override
  State<PinInputField> createState() => _PinInputFieldState();
}

class _PinInputFieldState extends State<PinInputField> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    
    final pin = _controllers.map((c) => c.text).join();
    widget.onChanged?.call(pin);
    
    if (pin.length == 4) {
      widget.onCompleted(pin);
    }
  }

  void _onBackspace(int index) {
    if (index > 0 && _controllers[index].text.isEmpty) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (index) {
            return SizedBox(
              width: 60,
              height: 60,
              child: TextFormField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                enabled: widget.enabled,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                obscureText: widget.obscureText,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: widget.errorText != null ? Colors.red : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: widget.errorText != null ? Colors.red : Colors.blue,
                    ),
                  ),
                ),
                onChanged: (value) => _onChanged(value, index),
                onTap: () {
                  _controllers[index].selection = TextSelection.fromPosition(
                    TextPosition(offset: _controllers[index].text.length),
                  );
                },
                onEditingComplete: () {
                  if (index < 3) {
                    _focusNodes[index + 1].requestFocus();
                  }
                },
                onFieldSubmitted: (_) {
                  if (index < 3) {
                    _focusNodes[index + 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ],
    );
  }
}