import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/spending_category.dart';
import '../services/ledger_repository.dart';
import '../widgets/stats_monthly_bar_chart.dart';
import 'stats_category_detail_sheet.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({
    super.key,
    required this.focusedMonth,
    required this.onMonthChanged,
  });

  final DateTime focusedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const _compositionPreviewCount = 5;

  bool _showExpense = true;
  bool _compositionExpanded = false;

  @override
  void didUpdateWidget(covariant StatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedMonth.year != widget.focusedMonth.year ||
        oldWidget.focusedMonth.month != widget.focusedMonth.month) {
      _compositionExpanded = false;
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.focusedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 1, 12),
      helpText: '选择月份',
    );
    if (picked == null || !mounted) return;
    widget.onMonthChanged(DateTime(picked.year, picked.month));
  }

  List<StatsMonthlyBarPoint> _lastSixMonths(LedgerRepository repo) {
    final end = widget.focusedMonth;
    final points = <StatsMonthlyBarPoint>[];
    for (var i = 0; i < 6; i++) {
      final month = DateTime(end.year, end.month - (5 - i));
      final amount = _showExpense
          ? repo.totalExpenseForMonth(month)
          : repo.totalIncomeForMonth(month);
      points.add(
        StatsMonthlyBarPoint(
          month: month,
          monthLabel: '${month.month}月',
          amount: amount,
          isFocused: i == 5,
        ),
      );
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LedgerRepository>(
      builder: (context, repo, _) {
        final month = widget.focusedMonth;
        final monthLabel = DateFormat('yyyy年M月').format(month);
        final prevMonth = DateTime(month.year, month.month - 1);
        final prevLabel = DateFormat('yyyy年M月').format(prevMonth);

        final byCategory = _showExpense
            ? repo.expenseByCategoryForMonth(month)
            : repo.incomeByCategoryForMonth(month);
        final total = _showExpense
            ? repo.totalExpenseForMonth(month)
            : repo.totalIncomeForMonth(month);
        final prevTotal = _showExpense
            ? repo.totalExpenseForMonth(prevMonth)
            : repo.totalIncomeForMonth(prevMonth);

        final budget = _showExpense ? repo.monthlyExpenseLimit : null;
        final remaining =
            _showExpense ? repo.budgetRemaining(month) : null;

        final sorted = byCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final recentPoints = _lastSixMonths(repo);
        final compositionTitle = _showExpense ? '支出构成' : '入账构成';

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: ColoredBox(
            color: WechatBillApp.wechatGreen,
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: _StatsGreenHeader(
                    monthLabel: monthLabel,
                    showExpense: _showExpense,
                    total: total,
                    onPickMonth: _pickMonth,
                    onToggleExpense: (v) => setState(() {
                      _showExpense = v;
                      _compositionExpanded = false;
                    }),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (budget != null) ...[
                            Text(
                              '限额 ¥${budget.toStringAsFixed(2)} · '
                              '${remaining != null && remaining >= 0 ? '结余' : '超支'} '
                              '¥${(remaining ?? 0).abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                color: remaining != null && remaining < 0
                                    ? Colors.red.shade700
                                    : Colors.grey.shade700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _MonthOverMonthCompare(
                            currentLabel: monthLabel,
                            previousLabel: prevLabel,
                            currentTotal: total,
                            previousTotal: prevTotal,
                            showExpense: _showExpense,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            compositionTitle,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 12),
                          if (sorted.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  '$monthLabel 暂无${_showExpense ? '支出' : '入账'}数据',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ),
                            )
                          else ...[
                            ...(_compositionExpanded
                                    ? sorted
                                    : sorted.take(_compositionPreviewCount))
                                .map((e) {
                              final ratio = total > 0 ? e.value / total : 0.0;
                              return _CategoryListTile(
                                category: e.key,
                                amount: e.value,
                                ratio: ratio,
                                onTap: () => showStatsCategoryDetailSheet(
                                  context,
                                  month: month,
                                  category: e.key,
                                  expense: _showExpense,
                                ),
                              );
                            }),
                            if (sorted.length > _compositionPreviewCount)
                              Center(
                                child: TextButton.icon(
                                  onPressed: () => setState(
                                    () => _compositionExpanded =
                                        !_compositionExpanded,
                                  ),
                                  icon: Icon(
                                    _compositionExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 20,
                                  ),
                                  label: Text(
                                    _compositionExpanded
                                        ? '收起'
                                        : '展开更多（${sorted.length - _compositionPreviewCount}）',
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(height: 28),
                          Divider(height: 1, color: Colors.grey.shade200),
                          const SizedBox(height: 20),
                          StatsMonthlyBarChart(
                            points: recentPoints,
                            onMonthTap: widget.onMonthChanged,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatsGreenHeader extends StatelessWidget {
  const _StatsGreenHeader({
    required this.monthLabel,
    required this.showExpense,
    required this.total,
    required this.onPickMonth,
    required this.onToggleExpense,
  });

  final String monthLabel;
  final bool showExpense;
  final double total;
  final VoidCallback onPickMonth;
  final ValueChanged<bool> onToggleExpense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 20),
      child: Column(
        children: [
          const Text(
            '记账本',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onPickMonth,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              monthLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      showExpense ? '共支出' : '共入账',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥ ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              _ExpenseIncomeToggle(
                showExpense: showExpense,
                onChanged: onToggleExpense,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpenseIncomeToggle extends StatelessWidget {
  const _ExpenseIncomeToggle({
    required this.showExpense,
    required this.onChanged,
  });

  final bool showExpense;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            label: '支出',
            selected: showExpense,
            onTap: () => onChanged(true),
          ),
          _ToggleChip(
            label: '入账',
            selected: !showExpense,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.35)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthOverMonthCompare extends StatelessWidget {
  const _MonthOverMonthCompare({
    required this.currentLabel,
    required this.previousLabel,
    required this.currentTotal,
    required this.previousTotal,
    required this.showExpense,
  });

  final String currentLabel;
  final String previousLabel;
  final double currentTotal;
  final double previousTotal;
  final bool showExpense;

  @override
  Widget build(BuildContext context) {
    final diff = currentTotal - previousTotal;
    final hasCompare = currentTotal > 0 || previousTotal > 0;
    final maxBar = [currentTotal, previousTotal]
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '较上月',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
            ),
            if (!hasCompare) ...[
              const SizedBox(height: 12),
              Text(
                '本月与上月均无${showExpense ? '支出' : '入账'}，暂无可对比数据',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ] else ...[
              const SizedBox(height: 16),
              _CompareBarRow(
                label: previousLabel,
                amount: previousTotal,
                ratio: maxBar > 0 ? previousTotal / maxBar : 0,
                barColor: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              _CompareBarRow(
                label: currentLabel,
                amount: currentTotal,
                ratio: maxBar > 0 ? currentTotal / maxBar : 0,
                barColor: WechatBillApp.wechatGreen,
              ),
              const SizedBox(height: 14),
              _CompareSummary(
                diff: diff,
                previousTotal: previousTotal,
                showExpense: showExpense,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompareBarRow extends StatelessWidget {
  const _CompareBarRow({
    required this.label,
    required this.amount,
    required this.ratio,
    required this.barColor,
  });

  final String label;
  final double amount;
  final double ratio;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ),
            Text(
              '¥${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            color: barColor,
          ),
        ),
      ],
    );
  }
}

class _CompareSummary extends StatelessWidget {
  const _CompareSummary({
    required this.diff,
    required this.previousTotal,
    required this.showExpense,
  });

  final double diff;
  final double previousTotal;
  final bool showExpense;

  @override
  Widget build(BuildContext context) {
    if (diff.abs() < 0.005 && previousTotal > 0) {
      return Text(
        '较上月 持平',
        style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
      );
    }
    if (diff.abs() < 0.005) {
      return Text(
        '较上月 均为 ¥0',
        style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
      );
    }

    final increased = diff > 0;
    final color = increased ? Colors.red.shade700 : Colors.green.shade700;
    final icon = increased ? Icons.arrow_upward : Icons.arrow_downward;
    final pctText = previousTotal > 0
        ? '（${(diff / previousTotal * 100).abs().toStringAsFixed(1)}%）'
        : '（上月无数据）';
    final verb = showExpense
        ? (increased ? '多支' : '少支')
        : (increased ? '多入' : '少入');

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '较上月 $verb ¥${diff.abs().toStringAsFixed(2)} $pctText',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryListTile extends StatelessWidget {
  const _CategoryListTile({
    required this.category,
    required this.amount,
    required this.ratio,
    required this.onTap,
  });

  final BookCategory category;
  final double amount;
  final double ratio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final green = WechatBillApp.wechatGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: WechatBillApp.wechatGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(category.icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category.label,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    Text(
                      '¥${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(ratio * 100).toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: Colors.grey.shade200,
                color: green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
