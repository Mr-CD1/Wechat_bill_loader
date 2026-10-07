import 'spending_category.dart';

class BillRecord {
  BillRecord({
    required this.id,
    required this.date,
    required this.transactionType,
    required this.counterparty,
    required this.flow,
    required this.amount,
    required this.category,
    this.note = '',
  });

  final String id;
  final DateTime date;
  final String transactionType;
  final String counterparty;
  /// 收 / 支
  final String flow;
  final double amount;
  BookCategory category;
  final String note;

  bool get isExpense => flow == '支出';

  bool get isIncome => flow == '收入';

  String get importFingerprint =>
      '${date.toIso8601String().substring(0, 10)}|$transactionType|$counterparty|$flow|$amount';

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'transactionType': transactionType,
        'counterparty': counterparty,
        'flow': flow,
        'amount': amount,
        'category': category.name,
        'note': note,
      };

  factory BillRecord.fromJson(Map<String, dynamic> json) {
    final categoryName = json['category'] as String? ?? BookCategory.otherExpense.name;
    return BillRecord(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      transactionType: json['transactionType'] as String? ?? '',
      counterparty: json['counterparty'] as String? ?? '',
      flow: json['flow'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      category: BookCategory.values.byName(categoryName),
      note: json['note'] as String? ?? '',
    );
  }

  BillRecord copyWith({BookCategory? category}) {
    return BillRecord(
      id: id,
      date: date,
      transactionType: transactionType,
      counterparty: counterparty,
      flow: flow,
      amount: amount,
      category: category ?? this.category,
      note: note,
    );
  }
}

/// 从 Excel 解析出的原始行（尚未入库）
class ParsedBillRow {
  ParsedBillRow({
    required this.date,
    required this.transactionType,
    required this.counterparty,
    required this.flow,
    required this.amount,
  });

  final DateTime date;
  final String transactionType;
  final String counterparty;
  final String flow;
  final double amount;

  bool get bookable => flow == '支出' || flow == '收入';
}
