import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/ledger_repository.dart';
import 'merchant_rules_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.onImportBill});

  final VoidCallback onImportBill;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _limitController = TextEditingController();
  bool _dirty = false;

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _syncFromRepo(LedgerRepository repo) {
    if (_dirty) return;
    final limit = repo.monthlyExpenseLimit;
    _limitController.text =
        limit != null && limit > 0 ? limit.toStringAsFixed(0) : '';
  }

  Future<void> _saveLimit(LedgerRepository repo) async {
    final text = _limitController.text.trim().replaceAll(',', '');
    if (text.isEmpty) {
      await repo.setMonthlyExpenseLimit(null);
      setState(() => _dirty = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清除每月支出限额')),
        );
      }
      return;
    }
    final value = double.tryParse(text);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入大于 0 的金额')),
      );
      return;
    }
    await repo.setMonthlyExpenseLimit(value);
    setState(() => _dirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存每月支出限额')),
      );
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空账本'),
        content: const Text('将删除本机全部记账记录，且不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<LedgerRepository>().clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LedgerRepository>(
      builder: (context, repo, _) {
        _syncFromRepo(repo);
        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('每月支出限额', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '适用于每个月；明细与统计中的「限额」「结余」均按此计算。',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _limitController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: '限额（元）',
                  hintText: '例如 3000',
                  border: OutlineInputBorder(),
                  prefixText: '¥ ',
                ),
                onChanged: (_) => _dirty = true,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _saveLimit(repo),
                child: const Text('保存限额'),
              ),
              const SizedBox(height: 24),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('导入微信支付账单'),
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.onImportBill,
              ),
              ListTile(
                leading: const Icon(Icons.store_outlined),
                title: const Text('商家分类规则'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MerchantRulesScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
                title: Text('清空账本', style: TextStyle(color: Colors.red.shade700)),
                onTap: () => _confirmClear(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
