import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../services/ledger_repository.dart';
import 'add_manual_expense_sheet.dart';
import 'ledger_list_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  static const _fabOpacityScrolling = 0.45;
  double _fabOpacity = 1.0;

  void _onListScrolling(bool scrolling) {
    final next = scrolling ? _fabOpacityScrolling : 1.0;
    if (_fabOpacity == next) return;
    setState(() => _fabOpacity = next);
  }

  Future<void> _importBill() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法读取文件，请重试')),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repo = context.read<LedgerRepository>();
      final importResult = await repo.importFromBytes(bytes);
      if (!mounted) return;
      Navigator.of(context).pop();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导入完成'),
          content: Text(
            '共解析 ${importResult.totalParsed} 条\n'
            '新增入账 ${importResult.imported} 条\n'
            '跳过（非收/支）${importResult.skippedNeutral} 条\n'
            '重复跳过 ${importResult.duplicates} 条',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      LedgerListScreen(
        focusedMonth: _focusedMonth,
        onMonthChanged: (m) => setState(() => _focusedMonth = m),
        onListScrolling: _onListScrolling,
      ),
      StatsScreen(
        focusedMonth: _focusedMonth,
        onMonthChanged: (m) => setState(() => _focusedMonth = m),
      ),
      SettingsScreen(onImportBill: _importBill),
    ];

    return Scaffold(
      appBar: _index == 1
          ? null
          : AppBar(
              title: const Text('记账本'),
              actions: [
                if (_index == 0)
                  IconButton(
                    tooltip: '记一笔',
                    onPressed: () => showAddManualExpenseSheet(
                      context,
                      initialDate: DateTime(
                        _focusedMonth.year,
                        _focusedMonth.month,
                        DateTime.now().day,
                      ),
                      onMonthFocus: (m) => setState(() => _focusedMonth = m),
                    ),
                    icon: const Icon(Icons.add),
                  ),
              ],
            ),
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: _index == 0
          ? AnimatedOpacity(
              opacity: _fabOpacity,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'manual_expense',
                    onPressed: () => showAddManualExpenseSheet(
                      context,
                      initialDate: DateTime(
                        _focusedMonth.year,
                        _focusedMonth.month,
                        DateTime.now().day,
                      ),
                      onMonthFocus: (m) => setState(() => _focusedMonth = m),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('记一笔'),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    heroTag: 'import_bill',
                    onPressed: _importBill,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('导入账单'),
                  ),
                ],
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          if (i != 0) _fabOpacity = 1.0;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '明细',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
        indicatorColor: WechatBillApp.wechatGreen.withValues(alpha: 0.2),
      ),
    );
  }
}
