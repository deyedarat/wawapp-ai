import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:core_shared/core_shared.dart';
import '../../models/order.dart' as app_order;
import '../../widgets/error_screen.dart';
import 'providers/history_providers.dart';

class DriverHistoryScreen extends ConsumerWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(driverHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات المنتهية'),
        centerTitle: true,
      ),
      body: historyAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد طلبات في السجل'),
                ],
              ),
            );
          }

          return _buildGroupedHistory(orders);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          final appError = AppError.from(error);
          return ErrorScreen(
            message: appError.toUserMessage(),
            onRetry: () => ref.refresh(driverHistoryProvider),
          );
        },
      ),
    );
  }

  Widget _buildGroupedHistory(List<app_order.Order> orders) {
    final grouped = <DateCategory, List<app_order.Order>>{};

    for (final order in orders) {
      final date = order.completedAt ?? order.updatedAt;
      final category = getDateCategory(date);
      grouped.putIfAbsent(category, () => []).add(order);
    }

    return ListView(
      children: [
        if (grouped.containsKey(DateCategory.today))
          _buildSection(getDateCategoryLabel(DateCategory.today),
              grouped[DateCategory.today]!),
        if (grouped.containsKey(DateCategory.yesterday))
          _buildSection(getDateCategoryLabel(DateCategory.yesterday),
              grouped[DateCategory.yesterday]!),
        if (grouped.containsKey(DateCategory.thisWeek))
          _buildSection(getDateCategoryLabel(DateCategory.thisWeek),
              grouped[DateCategory.thisWeek]!),
        if (grouped.containsKey(DateCategory.older))
          _buildSection(getDateCategoryLabel(DateCategory.older),
              grouped[DateCategory.older]!),
      ],
    );
  }

  Widget _buildSection(String title, List<app_order.Order> orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        ...orders.map((order) => _OrderHistoryTile(order: order)),
      ],
    );
  }
}

class _OrderHistoryTile extends StatelessWidget {
  final app_order.Order order;

  const _OrderHistoryTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final displayDate = order.completedAt ?? order.updatedAt;
    final completedDate = displayDate != null 
        ? dateFormat.format(displayDate)
        : 'غير محدد';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text('طلب #${order.id.substring(0, 8)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${order.pickup.label} ← ${order.dropoff.label}'),
            Text('الحالة: ${order.orderStatus.toArabicLabel()}'),
            Text('$completedDate'),
          ],
        ),
        trailing: Text(
          '${order.price} MRU',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () {
          context.pushNamed('orderDetails', extra: order);
        },
      ),
    );
  }
}
    );
  }
}

