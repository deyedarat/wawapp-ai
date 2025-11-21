import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../services/analytics_service.dart';
import '../../services/driver_status_service.dart';
import 'dart:developer' as dev;

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _isOnline = false;
  bool _isTogglingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadOnlineStatus();
  }

  Future<void> _loadOnlineStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final isOnline =
          await DriverStatusService.instance.getOnlineStatus(user.uid);
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        dev.log('[DriverHome] Error loading online status: $e');
      }
    }
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطأ: المستخدم غير مسجل الدخول')),
        );
      }
      return;
    }

    if (_isTogglingStatus) return;

    setState(() {
      _isTogglingStatus = true;
    });

    try {
      if (value) {
        await DriverStatusService.instance.setOnline(user.uid);
      } else {
        await DriverStatusService.instance.setOffline(user.uid);
      }

      if (mounted) {
        setState(() {
          _isOnline = value;
          _isTogglingStatus = false;
        });
      }

      if (kDebugMode) {
        dev.log(
            '[Matching] DriverHomeScreen: Driver toggled online status to: $value');
      }
    } catch (e) {
      if (kDebugMode) {
        dev.log('[DriverHome] Error toggling status: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحديث الحالة: $e')),
        );
        setState(() {
          _isTogglingStatus = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      final user = FirebaseAuth.instance.currentUser;
      dev.log('[Matching] DriverHomeScreen: Building home screen');
      dev.log('[Matching] DriverHomeScreen: Driver online status: $_isOnline');
      dev.log('[Matching] DriverHomeScreen: Driver ID: ${user?.uid ?? "not authenticated"}');
    }

    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.title),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.account_balance_wallet),
              onPressed: () => context.push('/wallet'),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'signout') {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    try {
                      await DriverStatusService.instance.setOffline(user.uid);
                    } catch (e) {
                      if (kDebugMode) {
                        dev.log('[DriverHome] Error setting offline on logout: $e');
                      }
                    }
                  }
                  await AnalyticsService.instance.logLogoutClicked();
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'signout',
                  child: Text('Sign out'),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: _isOnline ? Colors.green[100] : Colors.grey[300],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isOnline ? l10n.online : l10n.offline,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Switch(
                    value: _isOnline,
                    onChanged: _isTogglingStatus ? null : _toggleOnlineStatus,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.nearby_requests,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          if (kDebugMode) {
                            dev.log('[Matching] DriverHomeScreen: Navigating to nearby orders screen');
                          }
                          context.push('/nearby');
                        },
                        child: const Text('عرض الكل'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/earnings'),
                    icon: const Icon(Icons.account_balance_wallet),
                    label: const Text('الأرباح'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/history'),
                    icon: const Icon(Icons.history),
                    label: const Text('السجل'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Text(_isOnline ? 'في انتظار الطلبات...' : 'غير متصل'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
