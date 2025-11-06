import 'package:flutter/material.dart';
import '../../../core/logs/app_log.dart';

class DebugLogPanel extends StatefulWidget {
  const DebugLogPanel({super.key});

  @override
  State<DebugLogPanel> createState() => _DebugLogPanelState();
}

class _DebugLogPanelState extends State<DebugLogPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Icon(_expanded ? Icons.close : Icons.bug_report),
          ),
          if (_expanded)
            Container(
              width: 300,
              height: 200,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Debug Logs',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const Divider(color: Colors.grey),
                  Expanded(
                    child: ListView.builder(
                      itemCount: AppLog.getLogs().length,
                      itemBuilder: (context, index) {
                        final log = AppLog.getLogs()[index];
                        return Text(
                          log,
                          style: TextStyle(
                            color: log.contains('ERROR')
                                ? Colors.red
                                : Colors.green,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
