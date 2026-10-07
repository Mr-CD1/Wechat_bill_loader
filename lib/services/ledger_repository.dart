import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/bill_record.dart';
import '../models/merchant_category_rule.dart';
import '../models/spending_category.dart';
import 'category_classifier.dart';
import 'wechat_bill_parser.dart';

class LedgerRepository extends ChangeNotifier {
  LedgerRepository({
    WechatBillParser? parser,
    CategoryClassifier? classifier,
  })  : _parser = parser ?? WechatBillParser(),
        _classifier = classifier ?? CategoryClassifier();

  final WechatBillParser _parser;
  final CategoryClassifier _classifier;
  final _uuid = const Uuid();

  final List<BillRecord> _records = [];
  final List<MerchantCategoryRule> _merchantRules = [];
  /// 每月支出限额（全局，各月共用）
  double? _monthlyExpenseLimit;

  List<BillRecord> get records => List.unmodifiable(_records);
  List<MerchantCategoryRule> get merchantRules => List.unmodifiable(_merchantRules);

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    await _loadMerchantRules();
    await _loadSettings();
    _classifier.updateMerchantRules(_merchantRules);

    final file = await _ledgerFile();
    if (await file.exists()) {
      final text = await file.readAsString();
      final list = jsonDecode(text) as List<dynamic>;
      _records
        ..clear()
        ..addAll(list.map((e) => BillRecord.fromJson(e as Map<String, dynamic>)));
      _records.sort((a, b) => b.date.compareTo(a.date));
    }
    _loaded = true;
    notifyListeners();
  }

  Future<ImportResult> importFromBytes(List<int> bytes) async {
    final parsed = _parser.parseBytes(Uint8List.fromList(bytes));
    var imported = 0;
    var skipped = 0;
    var duplicate = 0;

    final existing = _records.map((r) => r.importFingerprint).toSet();

    for (final row in parsed) {
      if (!row.bookable) {
        skipped++;
        continue;
      }

      final fingerprint =
          '${row.date.toIso8601String().substring(0, 10)}|${row.transactionType}|${row.counterparty}|${row.flow}|${row.amount}';
      if (existing.contains(fingerprint)) {
        duplicate++;
        continue;
      }

      final category = _classifier.classify(row);
      _records.add(BillRecord(
        id: _uuid.v4(),
        date: row.date,
        transactionType: row.transactionType,
        counterparty: row.counterparty,
        flow: row.flow,
        amount: row.amount,
        category: category,
      ));
      existing.add(fingerprint);
      imported++;
    }

    _records.sort((a, b) => b.date.compareTo(a.date));
    await _persistRecords();
    notifyListeners();

    return ImportResult(
      totalParsed: parsed.length,
      imported: imported,
      skippedNeutral: skipped,
      duplicates: duplicate,
    );
  }

  Future<void> updateCategory(
    String id,
    BookCategory category, {
    bool rememberMerchant = false,
    bool applyToExisting = true,
  }) async {
    final index = _records.indexWhere((r) => r.id == id);
    if (index < 0) return;

    _records[index].category = category;

    if (rememberMerchant) {
      final keyword = _records[index].counterparty.trim();
      if (keyword.isNotEmpty) {
        await upsertMerchantRule(
          merchantKeyword: keyword,
          category: category,
          applyToExisting: applyToExisting,
        );
      }
    } else {
      await _persistRecords();
      notifyListeners();
    }
  }

  /// 手动添加一笔支出（非微信账单）
  Future<BillRecord> addManualExpense({
    required DateTime date,
    required double amount,
    required String counterparty,
    required BookCategory category,
    bool rememberMerchant = false,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('金额必须大于 0');
    }
    if (!category.isExpense) {
      throw ArgumentError('请选择支出分类');
    }

    final day = DateTime(date.year, date.month, date.day);
    final record = BillRecord(
      id: _uuid.v4(),
      date: day,
      transactionType: '手动记账',
      counterparty: counterparty.trim(),
      flow: '支出',
      amount: double.parse(amount.toStringAsFixed(2)),
      category: category,
    );

    _records.add(record);
    _records.sort((a, b) => b.date.compareTo(a.date));
    await _persistRecords();
    notifyListeners();

    if (rememberMerchant && record.counterparty.isNotEmpty) {
      await upsertMerchantRule(
        merchantKeyword: record.counterparty,
        category: category,
        applyToExisting: false,
      );
    }

    return record;
  }

  /// 新增或更新商家规则（同一关键词只保留一条）
  Future<void> upsertMerchantRule({
    required String merchantKeyword,
    required BookCategory category,
    bool applyToExisting = true,
  }) async {
    final keyword = merchantKeyword.trim();
    if (keyword.isEmpty) return;

    final normalized = keyword.toLowerCase();
    final existingIndex = _merchantRules.indexWhere(
      (r) => r.merchantKeyword.trim().toLowerCase() == normalized,
    );

    if (existingIndex >= 0) {
      _merchantRules[existingIndex] = MerchantCategoryRule(
        id: _merchantRules[existingIndex].id,
        merchantKeyword: keyword,
        category: category,
      );
    } else {
      _merchantRules.add(MerchantCategoryRule(
        id: _uuid.v4(),
        merchantKeyword: keyword,
        category: category,
      ));
    }

    _merchantRules.sort((a, b) => b.merchantKeyword.length.compareTo(a.merchantKeyword.length));
    _classifier.updateMerchantRules(_merchantRules);
    await _persistMerchantRules();

    if (applyToExisting) {
      _reclassifyByRules();
      await _persistRecords();
    }

    notifyListeners();
  }

  Future<void> deleteMerchantRule(String id) async {
    _merchantRules.removeWhere((r) => r.id == id);
    _classifier.updateMerchantRules(_merchantRules);
    await _persistMerchantRules();
    notifyListeners();
  }

  void _reclassifyByRules() {
    for (final record in _records) {
      final next = _classifier.classifyRecord(record);
      record.category = next;
    }
  }

  Future<void> deleteRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
    await _persistRecords();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _records.clear();
    await _persistRecords();
    notifyListeners();
  }

  double totalExpenseForMonth(DateTime month) {
    return _records
        .where((r) =>
            r.isExpense &&
            r.date.year == month.year &&
            r.date.month == month.month)
        .fold(0, (sum, r) => sum + r.amount);
  }

  double totalIncomeForMonth(DateTime month) {
    return _records
        .where((r) =>
            r.isIncome &&
            r.date.year == month.year &&
            r.date.month == month.month)
        .fold(0, (sum, r) => sum + r.amount);
  }

  /// 每月支出限额；未设置则返回 null
  double? get monthlyExpenseLimit => _monthlyExpenseLimit;

  /// 指定月份预算结余 = 限额 - 该月已支出；未设置限额则返回 null
  double? budgetRemaining(DateTime month) {
    final limit = _monthlyExpenseLimit;
    if (limit == null) return null;
    return double.parse((limit - totalExpenseForMonth(month)).toStringAsFixed(2));
  }

  Future<void> setMonthlyExpenseLimit(double? limit) async {
    if (limit == null || limit <= 0) {
      _monthlyExpenseLimit = null;
    } else {
      _monthlyExpenseLimit = double.parse(limit.toStringAsFixed(2));
    }
    await _persistSettings();
    notifyListeners();
  }

  Map<BookCategory, double> expenseByCategoryForMonth(DateTime month) {
    return _amountByCategoryForMonth(month, expense: true);
  }

  Map<BookCategory, double> incomeByCategoryForMonth(DateTime month) {
    return _amountByCategoryForMonth(month, expense: false);
  }

  Map<BookCategory, double> _amountByCategoryForMonth(
    DateTime month, {
    required bool expense,
  }) {
    final map = <BookCategory, double>{};
    for (final r in _records) {
      if (expense ? !r.isExpense : !r.isIncome) continue;
      if (r.date.year != month.year || r.date.month != month.month) continue;
      map[r.category] = (map[r.category] ?? 0) + r.amount;
    }
    return map;
  }

  List<BillRecord> recordsForMonthAndCategory(
    DateTime month,
    BookCategory category, {
    required bool expense,
  }) {
    final list = _records.where((r) {
      if (r.category != category) return false;
      if (expense ? !r.isExpense : !r.isIncome) return false;
      if (r.date.year != month.year || r.date.month != month.month) return false;
      return true;
    }).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<File> _ledgerFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/ledger_records.json');
  }

  Future<File> _merchantRulesFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/merchant_category_rules.json');
  }

  Future<File> _settingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/ledger_settings.json');
  }

  Future<File> _legacyMonthlyBudgetsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/monthly_budgets.json');
  }

  Future<void> _loadMerchantRules() async {
    final file = await _merchantRulesFile();
    if (!await file.exists()) return;
    final list = jsonDecode(await file.readAsString()) as List<dynamic>;
    _merchantRules
      ..clear()
      ..addAll(
        list.map((e) => MerchantCategoryRule.fromJson(e as Map<String, dynamic>)),
      );
    _merchantRules.sort((a, b) => b.merchantKeyword.length.compareTo(a.merchantKeyword.length));
  }

  Future<void> _persistRecords() async {
    final file = await _ledgerFile();
    final json = jsonEncode(_records.map((e) => e.toJson()).toList());
    await file.writeAsString(json);
  }

  Future<void> _persistMerchantRules() async {
    final file = await _merchantRulesFile();
    final json = jsonEncode(_merchantRules.map((e) => e.toJson()).toList());
    await file.writeAsString(json);
  }

  Future<void> _loadSettings() async {
    final file = await _settingsFile();
    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final limit = data['monthlyExpenseLimit'];
      _monthlyExpenseLimit =
          limit == null ? null : (limit as num).toDouble();
      return;
    }

    // 兼容旧版按月份存的限额：取任意一条作为全局限额
    final legacy = await _legacyMonthlyBudgetsFile();
    if (await legacy.exists()) {
      final map = jsonDecode(await legacy.readAsString()) as Map<String, dynamic>;
      if (map.isNotEmpty) {
        _monthlyExpenseLimit = (map.values.first as num).toDouble();
        await _persistSettings();
      }
    }
  }

  Future<void> _persistSettings() async {
    final file = await _settingsFile();
    await file.writeAsString(jsonEncode({
      'monthlyExpenseLimit': _monthlyExpenseLimit,
    }));
  }
}

class ImportResult {
  ImportResult({
    required this.totalParsed,
    required this.imported,
    required this.skippedNeutral,
    required this.duplicates,
  });

  final int totalParsed;
  final int imported;
  final int skippedNeutral;
  final int duplicates;
}
