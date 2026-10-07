import 'package:flutter/material.dart';

enum BookCategory {
  food('餐饮', Icons.restaurant, true),
  shopping('购物', Icons.shopping_bag, true),
  transport('交通', Icons.directions_car, true),
  entertainment('娱乐', Icons.sports_esports, true),
  home('居家', Icons.home, true),
  medical('医疗', Icons.local_hospital, true),
  education('教育', Icons.school, true),
  social('人情', Icons.card_giftcard, true),
  office('办公', Icons.work, true),
  salary('工资', Icons.account_balance_wallet, false),
  sideIncome('兼职', Icons.payments, false),
  investment('理财', Icons.trending_up, false),
  otherExpense('其他支出', Icons.more_horiz, true),
  otherIncome('其他收入', Icons.more_horiz, false);

  const BookCategory(this.label, this.icon, this.isExpense);

  final String label;
  final IconData icon;
  final bool isExpense;

  static List<BookCategory> expenseCategories() =>
      BookCategory.values.where((c) => c.isExpense).toList();

  static List<BookCategory> incomeCategories() =>
      BookCategory.values.where((c) => !c.isExpense).toList();
}
