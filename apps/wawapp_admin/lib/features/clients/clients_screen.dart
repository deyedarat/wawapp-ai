import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import 'package:intl/intl.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/status_badge.dart';
import '../../providers/admin_data_providers.dart';
import '../../services/admin_clients_service.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  bool? _verifiedFilter;

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(
      clientsStreamProvider(_verifiedFilter).stream,
    );
    final statsAsync = ref.watch(clientStatsProvider);

    return AdminScaffold(
      title: 'إدارة العملاء',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          statsAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (error, stack) => Text('خطأ في تحميل الإحصائيات: $error'),
            data: (stats) {
              final totalClients = stats['total'] ?? 0;
              final verifiedClients = stats['verified'] ?? 0;
              final blockedClients = stats['blocked'] ?? 0;

              return Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(AdminSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.people,
                                  color: AdminAppColors.primaryGreen,
                                  size: 24,
                                ),
                                SizedBox(width: AdminSpacing.sm),
                                Text(
                                  'إجمالي العملاء',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            SizedBox(height: AdminSpacing.sm),
                            Text(
                              '$totalClients',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    color: AdminAppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(AdminSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.verified_user,
                                  color: AdminAppColors.activeBlue,
                                  size: 24,
                                ),
                                SizedBox(width: AdminSpacing.sm),
                                Text(
                                  'موثّقون',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            SizedBox(height: AdminSpacing.sm),
                            Text(
                              '$verifiedClients',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    color: AdminAppColors.activeBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(AdminSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.block,
                                  color: AdminAppColors.errorLight,
                                  size: 24,
                                ),
                                SizedBox(width: AdminSpacing.sm),
                                Text(
                                  'محظورون',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            SizedBox(height: AdminSpacing.sm),
                            Text(
                              '$blockedClients',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    color: AdminAppColors.errorLight,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          SizedBox(height: AdminSpacing.xl),

          // Filters
          Row(
            children: [
              Text(
                'تصفية:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(width: AdminSpacing.md),
              FilterChip(
                label: const Text('الكل'),
                selected: _verifiedFilter == null,
                onSelected: (selected) {
                  setState(() {
                    _verifiedFilter = null;
                  });
                },
              ),
              SizedBox(width: AdminSpacing.sm),
              FilterChip(
                label: const Text('موثّقون'),
                selected: _verifiedFilter == true,
                onSelected: (selected) {
                  setState(() {
                    _verifiedFilter = true;
                  });
                },
              ),
              SizedBox(width: AdminSpacing.sm),
              FilterChip(
                label: const Text('غير موثّقين'),
                selected: _verifiedFilter == false,
                onSelected: (selected) {
                  setState(() {
                    _verifiedFilter = false;
                  });
                },
              ),
            ],
          ),

          SizedBox(height: AdminSpacing.lg),

          // Clients table
          Expanded(
            child: StreamBuilder<List<ClientProfile>>(
              stream: clientsAsync,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('خطأ في تحميل العملاء: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }

                final clients = snapshot.data ?? [];

                if (clients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AdminAppColors.textSecondaryLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا يوجد عملاء',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Card(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                AdminAppColors.backgroundLight,
                              ),
                              columns: [
                                DataColumn(
                                  label: Text(
                                    'الاسم',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'الهاتف',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'موثّق',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'إجمالي الطلبات',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'التقييم',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'اللغة المفضلة',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'تاريخ التسجيل',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'الإجراءات',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                              ],
                              rows: clients.map((client) {
                                final clientData = client.toJson();
                                final isBlocked = clientData['isBlocked'] == true;
                                final isVerified = clientData['isVerified'] == true;

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        client.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isBlocked
                                              ? AdminAppColors.textSecondaryLight
                                              : null,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(client.phone)),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isVerified)
                                            StatusBadge(
                                              label: 'موثّق',
                                              color: AdminAppColors.successLight,
                                            )
                                          else
                                            StatusBadge(
                                              label: 'غير موثّق',
                                              color: AdminAppColors.textSecondaryLight,
                                            ),
                                          if (isBlocked) ...[
                                            SizedBox(width: AdminSpacing.xs),
                                            StatusBadge(
                                              label: 'محظور',
                                              color: AdminAppColors.errorLight,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${client.totalTrips}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            size: 16,
                                            color: AdminAppColors.goldenYellow,
                                          ),
                                          SizedBox(width: AdminSpacing.xxs),
                                          Text(
                                            client.averageRating.toStringAsFixed(1),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _getLanguageLabel(client.preferredLanguage),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _formatDate(client.createdAt),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.visibility),
                                            onPressed: () {
                                              _showClientDetails(context, client);
                                            },
                                            tooltip: 'عرض التفاصيل',
                                            color: AdminAppColors.infoLight,
                                          ),
                                          if (!isVerified)
                                            IconButton(
                                              icon: const Icon(Icons.verified),
                                              onPressed: () {
                                                _showVerifyDialog(context, client);
                                              },
                                              tooltip: 'توثيق العميل',
                                              color: AdminAppColors.successLight,
                                            )
                                          else
                                            IconButton(
                                              icon: const Icon(Icons.cancel),
                                              onPressed: () {
                                                _showUnverifyDialog(context, client);
                                              },
                                              tooltip: 'إلغاء التوثيق',
                                              color: AdminAppColors.warningLight,
                                            ),
                                          if (!isBlocked)
                                            IconButton(
                                              icon: const Icon(Icons.block),
                                              onPressed: () {
                                                _showBlockDialog(context, client);
                                              },
                                              tooltip: 'حظر العميل',
                                              color: AdminAppColors.errorLight,
                                            )
                                          else
                                            IconButton(
                                              icon: const Icon(Icons.check_circle),
                                              onPressed: () {
                                                _showUnblockDialog(context, client);
                                              },
                                              tooltip: 'إلغاء الحظر',
                                              color: AdminAppColors.successLight,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: AdminSpacing.md),

                    Text(
                      'عرض ${clients.length} عميل',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AdminAppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getLanguageLabel(String lang) {
    switch (lang) {
      case 'ar':
        return 'العربية';
      case 'fr':
        return 'الفرنسية';
      case 'en':
        return 'الإنجليزية';
      default:
        return lang;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final formatter = DateFormat('yyyy-MM-dd', 'ar');
    return formatter.format(date);
  }

  void _showClientDetails(BuildContext context, ClientProfile client) {
    final clientData = client.toJson();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل العميل: ${client.name}'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('المعرف:', client.id),
                _buildDetailRow('الاسم:', client.name),
                _buildDetailRow('الهاتف:', client.phone),
                _buildDetailRow(
                  'موثّق:',
                  clientData['isVerified'] == true ? 'نعم' : 'لا',
                ),
                _buildDetailRow(
                  'محظور:',
                  clientData['isBlocked'] == true ? 'نعم' : 'لا',
                ),
                _buildDetailRow('إجمالي الطلبات:', '${client.totalTrips}'),
                _buildDetailRow(
                  'التقييم:',
                  client.averageRating.toStringAsFixed(1),
                ),
                _buildDetailRow(
                  'اللغة المفضلة:',
                  _getLanguageLabel(client.preferredLanguage),
                ),
                _buildDetailRow('تاريخ التسجيل:', _formatDate(client.createdAt)),
                if (client.updatedAt != null)
                  _buildDetailRow('آخر تحديث:', _formatDate(client.updatedAt)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AdminSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AdminAppColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }

  void _showVerifyDialog(BuildContext context, ClientProfile client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد التوثيق'),
        content: Text('هل أنت متأكد من توثيق العميل ${client.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جارٍ توثيق العميل...')),
              );

              final service = ref.read(adminClientsServiceProvider);
              final success = await service.setClientVerification(client.id, true);

              if (mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'تم توثيق العميل ${client.name}' : 'فشل توثيق العميل',
                    ),
                    backgroundColor: success
                        ? AdminAppColors.successLight
                        : AdminAppColors.errorLight,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminAppColors.successLight,
            ),
            child: const Text('نعم، توثيق'),
          ),
        ],
      ),
    );
  }

  void _showUnverifyDialog(BuildContext context, ClientProfile client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إلغاء التوثيق'),
        content: Text('هل أنت متأكد من إلغاء توثيق العميل ${client.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جارٍ إلغاء التوثيق...')),
              );

              final service = ref.read(adminClientsServiceProvider);
              final success = await service.setClientVerification(client.id, false);

              if (mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'تم إلغاء توثيق العميل ${client.name}' : 'فشل إلغاء التوثيق',
                    ),
                    backgroundColor: success
                        ? AdminAppColors.successLight
                        : AdminAppColors.errorLight,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminAppColors.warningLight,
            ),
            child: const Text('نعم، إلغاء التوثيق'),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context, ClientProfile client) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحظر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل أنت متأكد من حظر العميل ${client.name}؟'),
            SizedBox(height: AdminSpacing.md),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الحظر (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جارٍ حظر العميل...')),
              );

              final service = ref.read(adminClientsServiceProvider);
              final success = await service.blockClient(
                client.id,
                reason: reasonController.text.isNotEmpty
                    ? reasonController.text
                    : null,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'تم حظر العميل ${client.name}' : 'فشل حظر العميل',
                    ),
                    backgroundColor: success
                        ? AdminAppColors.successLight
                        : AdminAppColors.errorLight,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminAppColors.errorLight,
            ),
            child: const Text('نعم، حظر'),
          ),
        ],
      ),
    );
  }

  void _showUnblockDialog(BuildContext context, ClientProfile client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إلغاء الحظر'),
        content: Text('هل أنت متأكد من إلغاء حظر العميل ${client.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جارٍ إلغاء الحظر...')),
              );

              final service = ref.read(adminClientsServiceProvider);
              final success = await service.unblockClient(client.id);

              if (mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'تم إلغاء حظر العميل ${client.name}' : 'فشل إلغاء الحظر',
                    ),
                    backgroundColor: success
                        ? AdminAppColors.successLight
                        : AdminAppColors.errorLight,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminAppColors.successLight,
            ),
            child: const Text('نعم، إلغاء الحظر'),
          ),
        ],
      ),
    );
  }
}
