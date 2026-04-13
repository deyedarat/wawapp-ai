import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../utils/responsive_helper.dart';

/// Column definition for sortable data table
class DataTableColumn<T> {
  final String label;
  final String Function(T) getValue;
  final Widget Function(T)? buildCell;
  final bool sortable;
  final bool filterable;
  final double? width;
  final TextAlign textAlign;

  const DataTableColumn({
    required this.label,
    required this.getValue,
    this.buildCell,
    this.sortable = true,
    this.filterable = true,
    this.width,
    this.textAlign = TextAlign.start,
  });
}

/// Sortable and filterable data table widget
class SortableDataTable<T> extends StatefulWidget {
  final List<DataTableColumn<T>> columns;
  final List<T> data;
  final bool enableFiltering;
  final bool enableSorting;
  final bool enablePagination;
  final int rowsPerPage;
  final void Function(T)? onRowTap;
  final Widget Function(T)? buildActions;
  final bool isLoading;

  const SortableDataTable({
    super.key,
    required this.columns,
    required this.data,
    this.enableFiltering = true,
    this.enableSorting = true,
    this.enablePagination = true,
    this.rowsPerPage = 10,
    this.onRowTap,
    this.buildActions,
    this.isLoading = false,
  });

  @override
  State<SortableDataTable<T>> createState() => _SortableDataTableState<T>();
}

class _SortableDataTableState<T> extends State<SortableDataTable<T>> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  String _filterText = '';
  int _currentPage = 0;
  List<T> _filteredData = [];

  @override
  void initState() {
    super.initState();
    _filteredData = widget.data;
  }

  @override
  void didUpdateWidget(SortableDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _applyFilterAndSort();
    }
  }

  void _applyFilterAndSort() {
    setState(() {
      // Apply filter
      if (_filterText.isEmpty) {
        _filteredData = List.from(widget.data);
      } else {
        _filteredData = widget.data.where((item) {
          return widget.columns.any((column) {
            if (!column.filterable) return false;
            final value = column.getValue(item).toLowerCase();
            return value.contains(_filterText.toLowerCase());
          });
        }).toList();
      }

      // Apply sort
      if (_sortColumnIndex != null && widget.enableSorting) {
        final column = widget.columns[_sortColumnIndex!];
        _filteredData.sort((a, b) {
          final aValue = column.getValue(a);
          final bValue = column.getValue(b);
          final comparison = aValue.compareTo(bValue);
          return _sortAscending ? comparison : -comparison;
        });
      }

      // Reset to first page when data changes
      _currentPage = 0;
    });
  }

  void _onSort(int columnIndex) {
    if (!widget.enableSorting || !widget.columns[columnIndex].sortable) return;

    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
      _applyFilterAndSort();
    });
  }

  void _onFilterChanged(String value) {
    setState(() {
      _filterText = value;
      _applyFilterAndSort();
    });
  }

  List<T> _getPaginatedData() {
    if (!widget.enablePagination) return _filteredData;

    final startIndex = _currentPage * widget.rowsPerPage;
    final endIndex =
        (startIndex + widget.rowsPerPage).clamp(0, _filteredData.length);

    if (startIndex >= _filteredData.length) return [];
    return _filteredData.sublist(startIndex, endIndex);
  }

  int get _totalPages => widget.enablePagination
      ? (_filteredData.length / widget.rowsPerPage).ceil()
      : 1;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final paginatedData = _getPaginatedData();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter bar
        if (widget.enableFiltering)
          Padding(
            padding: const EdgeInsets.only(bottom: AdminSpacing.md),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث في الجدول...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AdminSpacing.md,
                  vertical: AdminSpacing.sm,
                ),
              ),
              onChanged: _onFilterChanged,
            ),
          ),

        // Table container with horizontal scroll on mobile
        Card(
          elevation: AdminElevation.low,
          child: widget.isLoading
              ? _buildLoadingState()
              : _filteredData.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: isMobile
                              ? MediaQuery.of(context).size.width - 48
                              : MediaQuery.of(context).size.width - 350,
                        ),
                        child: DataTable(
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _sortAscending,
                          headingRowColor: WidgetStateProperty.all(
                            AdminAppColors.backgroundLight,
                          ),
                          columns: widget.columns.asMap().entries.map((entry) {
                            final index = entry.key;
                            final column = entry.value;
                            return DataColumn(
                              label: Text(
                                column.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              onSort: column.sortable
                                  ? (_, __) => _onSort(index)
                                  : null,
                            );
                          }).toList(),
                          rows: paginatedData.map((item) {
                            return DataRow(
                              onSelectChanged: widget.onRowTap != null
                                  ? (_) => widget.onRowTap!(item)
                                  : null,
                              cells: widget.columns.map((column) {
                                return DataCell(
                                  column.buildCell != null
                                      ? column.buildCell!(item)
                                      : Text(
                                          column.getValue(item),
                                          textAlign: column.textAlign,
                                        ),
                                );
                              }).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
        ),

        // Pagination controls
        if (widget.enablePagination && _totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(top: AdminSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'عرض ${_currentPage * widget.rowsPerPage + 1} - ${((_currentPage + 1) * widget.rowsPerPage).clamp(0, _filteredData.length)} من ${_filteredData.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                      tooltip: 'الصفحة السابقة',
                    ),
                    Text(
                      'صفحة ${_currentPage + 1} من $_totalPages',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPage < _totalPages - 1
                          ? () => setState(() => _currentPage++)
                          : null,
                      tooltip: 'الصفحة التالية',
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 400,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AdminAppColors.primaryGreen,
          ),
          const SizedBox(height: AdminSpacing.md),
          Text(
            'جاري التحميل...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: AdminAppColors.textSecondaryLight.withOpacity(0.5),
          ),
          const SizedBox(height: AdminSpacing.md),
          Text(
            _filterText.isEmpty ? 'لا توجد بيانات' : 'لا توجد نتائج',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AdminAppColors.textSecondaryLight,
                ),
          ),
          if (_filterText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AdminSpacing.sm),
              child: Text(
                'جرب تغيير معايير البحث',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
