import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/bill_record.dart';
import '../models/spending_category.dart';
import '../services/ledger_repository.dart';

void showStatsCategoryDetailSheet(
  BuildContext context, {
  required DateTime month,
  required BookCategory category,
  required bool expense,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return _StatsCategoryDetailSheet(
          month: month,
          category: category,
          expense: expense,
          scrollController: scrollController,
        );
      },
    ),
  );
}

class _StatsCategoryDetailSheet extends StatelessWidget {
  const _StatsCategoryDetailSheet({
    required this.month,
    required this.category,
    required this.expense,
    required this.scrollController,
  });

  final DateTime month;
  final BookCategory category;
  final bool expense;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('yyyy年M月').format(month);

    return Consumer<LedgerRepository>(
      builder: (context, repo, _) {
        final records = repo.recordsForMonthAndCategory(
          month,
          category,
          expense: expense,
        );
        final total = records.fold<double>(0, (s, r) => s + r.amount);

        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          WechatBillApp.wechatGreen.withValues(alpha: 0.15),
                      child: Icon(category.icon, color: WechatBillApp.wechatGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.label,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$monthLabel · ${records.length} 笔 · '
                            '合计 ¥${total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: records.isEmpty
                    ? Center(
                        child: Text(
                          '暂无明细',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: records.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          indent: 72,
                          color: Colors.grey.shade100,
                        ),
                        itemBuilder: (context, index) {
                          return _DetailTile(
                            record: records[index],
                            expense: expense,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.record, required this.expense});

  final BillRecord record;
  final bool expense;

  @override
  Widget build(BuildContext context) {
    final place = record.counterparty.trim();
    final title = place.isNotEmpty ? place : '未标注商户';
    final dateStr = DateFormat('M月d日').format(record.date);
    final type = record.transactionType.trim();
    final subtitle = type.isNotEmpty ? '$dateStr · $type' : dateStr;
    final prefix = expense ? '-' : '+';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: WechatBillApp.wechatGreen.withValues(alpha: 0.12),
        child: Icon(record.category.icon, color: WechatBillApp.wechatGreen, size: 20),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '$prefix¥${record.amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: expense ? const Color(0xFF1A1A1A) : WechatBillApp.wechatGreen,
        ),
      ),
    );
  }
}
