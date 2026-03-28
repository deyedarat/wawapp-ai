import 'package:flutter/material.dart';
import '../services/analytics_service.dart';

class ErrorScreen extends StatefulWidget {
  final String message;
  final VoidCallback onRetry;
  final String? title;
  final String? screenName;
  final String? errorType;

  const ErrorScreen({
    super.key,
    required this.message,
    required this.onRetry,
    this.title,
    this.screenName,
    this.errorType,
  });

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {
  @override
  void initState() {
    super.initState();
    // Log error occurrence once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.instance.logError(
        errorType: widget.errorType ?? 'unknown',
        screen: widget.screenName ?? 'unknown',
        errorMessage: widget.message,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              widget.title ?? 'حدث خطأ',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: widget.onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
