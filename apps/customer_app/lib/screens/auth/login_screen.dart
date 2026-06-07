import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import 'package:shared/shared.dart';
import '../../providers/auth_provider.dart';

/// Login screen for the customer app.
class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<CustomerAuthProvider>(
          builder: (context, authProvider, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  _buildHeader(),
                  const SizedBox(height: 48),
                  _buildContent(authProvider),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Icon(
            Icons.checkroom,
            size: 50,
            color: Color(0xFF1565C0),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'تطبيق الزبون',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'تابع حالة ملابسك بسهولة',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(CustomerAuthProvider authProvider) {
    switch (authProvider.state) {
      case CustomerAuthState.initial:
      case CustomerAuthState.error:
        return _buildPhoneInput(authProvider);
      case CustomerAuthState.loading:
        return const LoadingWidget(message: 'جاري التحميل...');
      case CustomerAuthState.codeSent:
        return _buildOtpInput(authProvider);
      case CustomerAuthState.verifying:
        return const LoadingWidget(message: 'جاري التحقق...');
      case CustomerAuthState.profileSetup:
        return _buildProfileSetup(authProvider);
      case CustomerAuthState.authenticated:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed('/home');
        });
        return const LoadingWidget();
    }
  }

  Widget _buildPhoneInput(CustomerAuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'رقم الهاتف',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        PhoneInputField(
          controller: _phoneController,
          hintText: '2X XX XX XX',
          onSubmitted: () => _handleSendOtp(authProvider),
        ),
        if (authProvider.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            authProvider.errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 14),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => _handleSendOtp(authProvider),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text(
            'إرسال رمز التحقق',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpInput(CustomerAuthProvider authProvider) {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 56,
      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'تم إرسال رمز التحقق إلى',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          Formatters.formatPhoneDisplay(
            Validators.formatPhoneNumber(authProvider.phoneNumber),
          ),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        ),
        const SizedBox(height: 32),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Pinput(
            controller: _otpController,
            length: 6,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: defaultPinTheme.copyWith(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1565C0), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onCompleted: (pin) => _handleVerifyOtp(authProvider, pin),
          ),
        ),
        if (authProvider.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            authProvider.errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => _handleVerifyOtp(authProvider, _otpController.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text(
            'تحقق',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => authProvider.resendOtp(),
          child: const Text('إعادة إرسال الرمز'),
        ),
        TextButton(
          onPressed: () {
            _otpController.clear();
            authProvider.signOut();
          },
          child: const Text('تغيير رقم الهاتف'),
        ),
      ],
    );
  }

  Widget _buildProfileSetup(CustomerAuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'أكمل بياناتك',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'أدخل اسمك لإكمال التسجيل',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'الاسم الكامل',
            hintText: 'أدخل اسمك',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (authProvider.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            authProvider.errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 14),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => _handleCompleteProfile(authProvider),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text(
            'إكمال التسجيل',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _handleSendOtp(CustomerAuthProvider authProvider) {
    final phone = _phoneController.text.trim();
    if (!Validators.isValidPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم الهاتف غير صحيح'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    authProvider.sendOtp(phone);
  }

  void _handleVerifyOtp(CustomerAuthProvider authProvider, String otp) {
    if (!Validators.isValidOtp(otp)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل رمز التحقق كاملاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    authProvider.verifyOtp(otp);
  }

  void _handleCompleteProfile(CustomerAuthProvider authProvider) {
    final name = _nameController.text.trim();
    if (!Validators.isValidName(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل اسماً صحيحاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    authProvider.completeProfile(name);
  }
}
