import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/merchant_category_rule.dart';
import '../models/spending_category.dart';
import '../services/ledger_repository.dart';
import '../widgets/category_picker_sheet.dart';

class _NewRuleDraft {
  _NewRuleDraft({required this.keyword, required this.isExpense});
  final String keyword;
  final bool isExpense;
}

class MerchantRulesScreen extends StatelessWidget {
  const MerchantRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('商家分类'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加规则',
            onPressed: () => _showAddRuleDialog(context),
          ),
        ],
      ),
      body: Consumer<LedgerRepository>(
        builder: (context, repo, _) {
          final rules = repo.merchantRules;
          if (rules.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.store_outlined, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      '还没有商家规则',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '在明细里改分类时可勾选「记住商家」\n或点右上角 + 手动添加',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rules.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final rule = rules[index];
              return Dismissible(
                key: ValueKey(rule.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red.shade400,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) => _confirmDelete(context, rule),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(rule.category.icon, size: 20),
                  ),
                  title: Text(rule.merchantKeyword),
                  subtitle: Text('交易对方包含此名称 → ${rule.category.label}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editRule(context, rule),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddRuleDialog(BuildContext context) async {
    final keywordController = TextEditingController();
    var isExpense = true;

    final draft = await showDialog<_NewRuleDraft>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('添加商家规则'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: keywordController,
                decoration: const InputDecoration(
                  labelText: '商家关键词',
                  hintText: '如：美团、Steam、公司名称',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('支出类')),
                  ButtonSegment(value: false, label: Text('收入类')),
                ],
                selected: {isExpense},
                onSelectionChanged: (s) => setLocal(() => isExpense = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final text = keywordController.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(ctx, _NewRuleDraft(keyword: text, isExpense: isExpense));
              },
              child: const Text('下一步'),
            ),
          ],
        ),
      ),
    );

    if (draft == null || !context.mounted) return;

    final defaultCategory =
        draft.isExpense ? BookCategory.otherExpense : BookCategory.otherIncome;

    final picked = await showModalBottomSheet<CategoryPickerResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryPickerSheet(
        current: defaultCategory,
        isExpense: draft.isExpense,
      ),
    );

    if (picked == null || !context.mounted) return;

    await context.read<LedgerRepository>().upsertMerchantRule(
          merchantKeyword: draft.keyword,
          category: picked.category,
          applyToExisting: true,
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存商家分类规则')),
    );
  }

  Future<void> _editRule(BuildContext context, MerchantCategoryRule rule) async {
    final picked = await showModalBottomSheet<CategoryPickerResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryPickerSheet(
        current: rule.category,
        isExpense: rule.category.isExpense,
        merchantLabel: rule.merchantKeyword,
      ),
    );

    if (picked == null || !context.mounted) return;

    await context.read<LedgerRepository>().upsertMerchantRule(
          merchantKeyword: rule.merchantKeyword,
          category: picked.category,
          applyToExisting: true,
        );
  }

  Future<bool> _confirmDelete(BuildContext context, MerchantCategoryRule rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除规则'),
        content: Text('不再自动将「${rule.merchantKeyword}」归入 ${rule.category.label}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<LedgerRepository>().deleteMerchantRule(rule.id);
    }
    return ok ?? false;
  }
}
