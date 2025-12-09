import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../services/analytics_service.dart';
import '../../services/driver_status_service.dart';
import '../auth/providers/auth_service_provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import 'dart:developer' as dev;

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  bool _isOnline = false;
  bool _isTogglingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadOnlineStatus();
  }

  Future<void> _loadOnlineStatus() async {
    final authState = ref.read(authProvider);
    if (authState.user == null) return;

    try {
      final isOnline =
          await DriverStatusService.instance.getOnlineStatus(authState.user!.uid);
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    } on Object catch (e) {
      if (kDebugMode) {
        dev.log('[DriverHome] Error loading online status: $e');
      }
    }
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    final authState = ref.read(authProvider);
    if (authState.user == null) {
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
        await DriverStatusService.instance.setOnline(authState.user!.uid);
      } else {
        await DriverStatusService.instance.setOffline(authState.user!.uid);
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
    } on Object catch (e) {
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
      final authState = ref.watch(authProvider);
      dev.log('[Matching] DriverHomeScreen: Building home screen');
      dev.log('[Matching] DriverHomeScreen: Driver online status: $_isOnline');
      dev.log(
          '[Matching] DriverHomeScreen: Driver ID: ${authState.user?.uid ?? "not authenticated"}');
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
                if (value == 'profile') {
                  context.push('/profile');
                } else if (value == 'signout') {
                  final authState = ref.read(authProvider);
                  if (authState.user != null) {
                    try {
                      await DriverStatusService.instance.setOffline(authState.user!.uid);
                    } on Object catch (e) {
                      if (kDebugMode) {
                        dev.log(
                            '[DriverHome] Error setting offline on logout: $e');
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
                  value: 'profile',
                  child: Text('الملف الشخصي'),
                ),
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
            // Status Card
            Container(
              margin: EdgeInsets.all(DriverAppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isOnline
                      ? [DriverAppColors.onlineGreen, DriverAppColors.onlineGreen.withOpacity(0.8)]
                      : [DriverAppColors.offlineGrey, DriverAppColors.offlineGrey.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(DriverAppSpacing.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: (_isOnline ? DriverAppColors.onlineGreen : DriverAppColors.offlineGrey).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(DriverAppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOnline ? l10n.online : l10n.offline,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: DriverAppSpacing.xxs),
                        Text(
                          _isOnline ? 'جاهز لاستقبال الطلبات' : 'اذهب إلى الإنترنت لاستقبال الطلبات',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isOnline,
                      onChanged: _isTogglingStatus ? null : _toggleOnlineStatus,
                      activeColor: Colors.white,
                      activeTrackColor: Colors.white.withOpacity(0.5),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.white.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(DriverAppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Quick Actions
                    Text(
                      'الإجراءات السريعة',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: DriverAppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: DriverCard(
                            onTap: () => context.push('/nearby'),
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(DriverAppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: DriverAppColors.primaryLight.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.local_shipping,
                                    size: 32,
                                    color: DriverAppColors.primaryLight,
                                  ),
                                ),
                                SizedBox(height: DriverAppSpacing.sm),
                                Text(
                                  'الطلبات القريبة',
                                  style: Theme.of(context).textTheme.titleSmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: DriverAppSpacing.md),
                        Expanded(
                          child: DriverCard(
                            onTap: () => context.push('/earnings'),
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(DriverAppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: DriverAppColors.secondaryLight.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet,
                                    size: 32,
                                    color: DriverAppColors.secondaryLight,
                                  ),
                                ),
                                SizedBox(height: DriverAppSpacing.sm),
                                Text(
                                  'الأرباح',
                                  style: Theme.of(context).textTheme.titleSmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: DriverAppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: DriverCard(
                            onTap: () => context.push('/history'),
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(DriverAppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: DriverAppColors.infoLight.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.history,
                                    size: 32,
                                    color: DriverAppColors.infoLight,
                                  ),
                                ),
                                SizedBox(height: DriverAppSpacing.sm),
                                Text(
                                  'السجل',
                                  style: Theme.of(context).textTheme.titleSmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: DriverAppSpacing.md),
                        Expanded(
                          child: DriverCard(
                            onTap: () => context.push('/wallet'),
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(DriverAppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: DriverAppColors.successLight.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.wallet,
                                    size: 32,
                                    color: DriverAppColors.successLight,
                                  ),
                                ),
                                SizedBox(height: DriverAppSpacing.sm),
                                Text(
                                  'المحفظة',
                                  style: Theme.of(context).textTheme.titleSmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: DriverAppSpacing.lg),
                    // Today's Summary
                    Text(
                      'ملخص اليوم',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: DriverAppSpacing.md),
                    DriverCard(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'عدد الرحلات',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: DriverAppColors.textSecondaryLight,
                                    ),
                                  ),
                                  SizedBox(height: DriverAppSpacing.xxs),
                                  Text(
                                    '0',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: DriverAppColors.primaryLight,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: EdgeInsets.all(DriverAppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: DriverAppColors.primaryLight.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.local_shipping,
                                  size: 28,
                                  color: DriverAppColors.primaryLight,
                                ),
                              ),
                            ],
                          ),
                          Divider(height: DriverAppSpacing.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الأرباح',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: DriverAppColors.textSecondaryLight,
                                    ),
                                  ),
                                  SizedBox(height: DriverAppSpacing.xxs),
                                  Text(
                                    '0 MRU',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: DriverAppColors.successLight,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: EdgeInsets.all(DriverAppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: DriverAppColors.successLight.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.monetization_on,
                                  size: 28,
                                  color: DriverAppColors.successLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
