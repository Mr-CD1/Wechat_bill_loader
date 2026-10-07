import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wechat_bill/services/wechat_bill_parser.dart';

void main() {
  test('parse sample xlsx when file exists', () {
    const path =
        r'd:\Downloads\微信支付账单流水文件(20260821-20260921)_20260921185618.xlsx';
    final file = File(path);
    if (!file.existsSync()) {
      return;
    }
    final parser = WechatBillParser();
    final rows = parser.parseBytes(file.readAsBytesSync());
    expect(rows, isNotEmpty);
    expect(rows.first.date.year, greaterThan(2020));
    expect(rows.any((r) => r.bookable), isTrue);
  });
}
