import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/bill_record.dart';
import '../services/ledger_repository.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/record_tile.dart';
class LedgerListScreen extends StatelessWidget {
  const LedgerListScreen({
    super.key,
    required this.focusedMonth,
    required this.onMonthChanged,
    this.onListScrolling,
  });

  final DateTime focusedMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<bool>? onListScrolling;

  @override
  Widget build(BuildContext context) {
    return Consumer<LedgerRepository>(
      builder: (context, repo, _) {
        if (!repo.isLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final monthRecords = repo.records.where((r) {
          return r.isExpense &&
              r.date.year == focusedMonth.year &&
              r.date.month == focusedMonth.month;
        }).toList();

        final expense = repo.totalExpenseForMonth(focusedMonth);
        final budget = repo.monthlyExpenseLimit;
        final remaining = repo.budgetRemaining(focusedMonth);
        final grouped = _groupByDay(monthRecords);

        return Scaffold(
          body: Column(
            children: [
              _MonthSummaryCard(
                focusedMonth: focusedMonth,
                expense: expense,
                budgetLimit: budget,
                budgetRemaining: remaining,
                onPrev: () => onMonthChanged(
                  DateTime(focusedMonth.year, focusedMonth.month - 1),
                ),
                onNext: () => onMonthChanged(
                  DateTime(focusedMonth.year, focusedMonth.month + 1),
                ),
              ),
              Expanded(
                child: monthRecords.isEmpty
                    ? const _EmptyHint()
                    : NotificationListener<UserScrollNotification>(
                        onNotification: (notification) {
                          final scrolling =
                              notification.direction != ScrollDirection.idle;
                          onListScrolling?.call(scrolling);
                          return false;
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 160),
                          itemCount: grouped.length,
                          itemBuilder: (context, index) {
                            final entry = grouped[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                  child: Text(
                                    entry.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(color: Colors.grey.shade600),
                                  ),
                                ),
                                ...entry.records.map(
                                  (r) => RecordTile(
                                    record: r,
                                    onTap: () => _editCategory(context, r),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  static List<_DayGroup> _groupByDay(List<BillRecord> records) {
    final map = <String, List<BillRecord>>{};
    for (final r in records) {
      final key = DateFormat('yyyy-MM-dd').format(r.date);
      map.putIfAbsent(key, () => []).add(r);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return keys.map((k) => _DayGroup(label: k, records: map[k]!)).toList();
  }

  Future<void> _editCategory(BuildContext context, BillRecord record) async {
    final picked = await showModalBottomSheet<CategoryPickerResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryPickerSheet(
        current: record.category,
        isExpense: record.isExpense,
        merchantLabel: record.counterparty,
      ),
    );
    if (picked == null || !context.mounted) return;
    await context.read<LedgerRepository>().updateCategory(
          record.id,
          picked.category,
          rememberMerchant: picked.rememberMerchant,
        );
    if (!context.mounted) return;
    if (picked.rememberMerchant) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已记住该商家的分类')),
      );
    }
  }

}

class _DayGroup {
  _DayGroup({required this.label, required this.records});
  final String label;
  final List<BillRecord> records;
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
    required this.focusedMonth,
    required this.expense,
    required this.budgetLimit,
    required this.budgetRemaining,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime focusedMonth;
  final double expense;
  final double? budgetLimit;
  final double? budgetRemaining;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('yyyy年M月').format(focusedMonth);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left, color: Colors.white),
              ),
              Text(
                monthLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryColumn(
                  label: '已支出',
                  amount: expense,
                ),
              ),
              Container(width: 1, height: 44, color: Colors.white24),
              Expanded(
                child: _SummaryColumn(
                  label: '限额',
                  amount: budgetLimit,
                  placeholder: '未设置',
                ),
              ),
            ],
          ),
          if (budgetLimit != null && budgetRemaining != null) ...[
            const SizedBox(height: 12),
            Text(
              _remainingLabel(budgetRemaining!),
              style: TextStyle(
                color: budgetRemaining! >= 0 ? Colors.white : Colors.amber.shade200,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (budgetLimit == null) ...[
            const SizedBox(height: 8),
            Text(
              '在「设置」中配置每月限额后可查看结余',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _remainingLabel(double remaining) {
    if (remaining >= 0) {
      return '结余 ¥${remaining.toStringAsFixed(2)}';
    }
    return '已超支 ¥${(-remaining).toStringAsFixed(2)}';
  }
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({
    required this.label,
    required this.amount,
    this.placeholder,
  });

  final String label;
  final double? amount;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          amount != null ? '¥${amount!.toStringAsFixed(2)}' : (placeholder ?? '—'),
          style: TextStyle(
            color: Colors.white,
            fontSize: amount != null ? 20 : 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              '本月还没有支出记录',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右下角「导入账单」\n选择微信支付导出的 .xlsx 文件',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
