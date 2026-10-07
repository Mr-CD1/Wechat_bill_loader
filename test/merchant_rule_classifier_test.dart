import 'package:flutter_test/flutter_test.dart';
import 'package:wechat_bill/models/bill_record.dart';
import 'package:wechat_bill/models/merchant_category_rule.dart';
import 'package:wechat_bill/models/spending_category.dart';
import 'package:wechat_bill/services/category_classifier.dart';

void main() {
  test('merchant rule overrides default keywords', () {
    final classifier = CategoryClassifier(
      merchantRules: [
        MerchantCategoryRule(
          id: '1',
          merchantKeyword: 'Steam',
          category: BookCategory.education,
        ),
      ],
    );

    final row = ParsedBillRow(
      date: DateTime(2026, 9, 1),
      transactionType: '商户消费',
      counterparty: 'Valve Steam Purchase',
      flow: '支出',
      amount: 128.7,
    );

    expect(classifier.classify(row), BookCategory.education);
  });
}
