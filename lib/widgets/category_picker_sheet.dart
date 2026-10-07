import 'package:flutter/material.dart';

import '../models/spending_category.dart';

class CategoryPickerResult {
  const CategoryPickerResult({
    required this.category,
    required this.rememberMerchant,
  });

  final BookCategory category;
  final bool rememberMerchant;
}

class CategoryPickerSheet extends StatefulWidget {
  const CategoryPickerSheet({
    super.key,
    required this.current,
    required this.isExpense,
    this.merchantLabel,
  });

  final BookCategory current;
  final bool isExpense;
  final String? merchantLabel;

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  late BookCategory _selected;
  bool _rememberMerchant = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        widget.isExpense ? BookCategory.expenseCategories() : BookCategory.incomeCategories();
    final merchant = widget.merchantLabel?.trim() ?? '';
    final canRemember = merchant.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('选择分类', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((c) {
                final selected = c == _selected;
                return ChoiceChip(
                  label: Text(c.label),
                  avatar: Icon(c.icon, size: 18),
                  selected: selected,
                  onSelected: (_) => setState(() => _selected = c),
                );
              }).toList(),
            ),
            if (canRemember) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _rememberMerchant,
                onChanged: (v) => setState(() => _rememberMerchant = v ?? false),
                title: Text(
                  '记住商家「${_truncate(merchant, 18)}」',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: const Text('以后导入账单时，匹配该名称的交易自动归入此类'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                CategoryPickerResult(
                  category: _selected,
                  rememberMerchant: canRemember && _rememberMerchant,
                ),
              ),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  String _truncate(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}…';
  }
}
