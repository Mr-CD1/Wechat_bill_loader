import 'package:flutter/material.dart';

import '../models/bill_record.dart';

class RecordTile extends StatelessWidget {
  const RecordTile({
    super.key,
    required this.record,
    required this.onTap,
  });

  final BillRecord record;
  final VoidCallback onTap;

  static const _amountColor = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    final place = record.counterparty.trim();
    final subtitle = place.isNotEmpty ? place : '未标注商户';

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        child: Icon(record.category.icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(
        record.category.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '-¥${record.amount.toStringAsFixed(2)}',
        style: const TextStyle(
          color: _amountColor,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }
}
