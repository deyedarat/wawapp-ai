import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:core_shared/core_shared.dart';

class DebugMenuScreen extends StatelessWidget {
  const DebugMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('Debug menu only available in debug builds')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Debug Menu - Client')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Crashlytics', [
            ElevatedButton.icon(
              onPressed: () {
                WawLog.d('DebugMenu', 'Triggering test crash');
                CrashlyticsObserver.testCrash();
              },
              icon: const Icon(Icons.bug_report),
              label: const Text('Trigger Test Crash'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                WawLog.e('DebugMenu', 'Test non-fatal error', 
                  Exception('Test non-fatal exception'), StackTrace.current);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Non-fatal error logged')),
                );
              },
              icon: const Icon(Icons.error_outline),
              label: const Text('Log Non-Fatal Error'),
            ),
          ]),
          _buildSection('Logging', [
            ElevatedButton.icon(
              onPressed: () {
                WawLog.d('DebugMenu', 'Test debug log');
                WawLog.w('DebugMenu', 'Test warning log');
                WawLog.e('DebugMenu', 'Test error log');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Check console for logs')),
                );
              },
              icon: const Icon(Icons.list_alt),
              label: const Text('Test All Log Levels'),
            ),
          ]),
          _buildSection('Config', [
            _buildInfoTile('Performance Overlay', DebugConfig.enablePerformanceOverlay),
            _buildInfoTile('Provider Observer', DebugConfig.enableProviderObserver),
            _buildInfoTile('Verbose Logging', DebugConfig.enableVerboseLogging),
            _buildInfoTile('Crashlytics Non-Fatal', DebugConfig.enableNonFatalCrashlytics),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInfoTile(String label, bool value) {
    return ListTile(
      title: Text(label),
      trailing: Icon(value ? Icons.check_circle : Icons.cancel, 
        color: value ? Colors.green : Colors.grey),
    );
  }
}
