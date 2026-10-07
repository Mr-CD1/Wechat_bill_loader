import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/spending_category.dart';
import '../services/ledger_repository.dart';

Future<void> showAddManualExpenseSheet(
  BuildContext context, {
  DateTime? initialDate,
  ValueChanged<DateTime>? onMonthFocus,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AddManualExpenseSheet(
      initialDate: initialDate ?? DateTime.now(),
      onMonthFocus: onMonthFocus,
    ),
  );
}

class _AddManualExpenseSheet extends StatefulWidget {
  const _AddManualExpenseSheet({
    required this.initialDate,
    this.onMonthFocus,
  });

  final DateTime initialDate;
  final ValueChanged<DateTime>? onMonthFocus;

  @override
  State<_AddManualExpenseSheet> createState() => _AddManualExpenseSheetState();
}

class _AddManualExpenseSheetState extends State<_AddManualExpenseSheet> {
  late DateTime _date;
  BookCategory _category = BookCategory.otherExpense;
  final _amountController = TextEditingController();
  final _placeController = TextEditingController();
  bool _rememberMerchant = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    final amountText = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showError('请输入有效金额');
      return;
    }

    setState(() => _saving = true);
    try {
      final record = await context.read<LedgerRepository>().addManualExpense(
            date: _date,
            amount: amount,
            counterparty: _placeController.text,
            category: _category,
            rememberMerchant: _rememberMerchant,
          );
      if (!mounted) return;
      widget.onMonthFocus?.call(DateTime(record.date.year, record.date.month));
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已记一笔支出')),
      );
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final dateLabel = DateFormat('yyyy年M月d日').format(_date);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('记一笔', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('日期'),
            trailing: Text(dateLabel),
            onTap: _pickDate,
          ),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              labelText: '金额（元）',
              border: OutlineInputBorder(),
              prefixText: '¥ ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _placeController,
            decoration: const InputDecoration(
              labelText: '消费地点 / 商户',
              hintText: '如：现金买菜、路边停车',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('分类', style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BookCategory.expenseCategories().map((c) {
              final selected = c == _category;
              return ChoiceChip(
                label: Text(c.label),
                avatar: Icon(c.icon, size: 18),
                selected: selected,
                onSelected: (_) => setState(() => _category = c),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _rememberMerchant,
            onChanged: (v) => setState(() => _rememberMerchant = v ?? false),
            title: const Text('记住该商户的分类'),
            subtitle: const Text('需填写商户名称；导入账单时自动匹配'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
    );
  }
}
