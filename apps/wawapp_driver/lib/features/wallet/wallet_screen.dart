import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.wallet),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        l10n.total_earnings,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '0 MRU',
                        style: TextStyle(
                            fontSize: 36, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(l10n.today_earnings,
                          style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      const Text('0 MRU',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
