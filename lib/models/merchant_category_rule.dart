import 'spending_category.dart';

/// 用户自定义：某商家名称匹配 → 固定分类
class MerchantCategoryRule {
  MerchantCategoryRule({
    required this.id,
    required this.merchantKeyword,
    required this.category,
  });

  final String id;
  /// 与「交易对方」做包含匹配（不区分大小写）
  final String merchantKeyword;
  final BookCategory category;

  bool matchesCounterparty(String counterparty) {
    final keyword = merchantKeyword.trim().toLowerCase();
    if (keyword.isEmpty) return false;
    return counterparty.trim().toLowerCase().contains(keyword);
  }

  bool matchesFlow(String flow) {
    if (flow == '支出') return category.isExpense;
    if (flow == '收入') return !category.isExpense;
    return false;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'merchantKeyword': merchantKeyword,
        'category': category.name,
      };

  factory MerchantCategoryRule.fromJson(Map<String, dynamic> json) {
    return MerchantCategoryRule(
      id: json['id'] as String,
      merchantKeyword: json['merchantKeyword'] as String? ?? '',
      category: BookCategory.values.byName(json['category'] as String),
    );
  }
}
