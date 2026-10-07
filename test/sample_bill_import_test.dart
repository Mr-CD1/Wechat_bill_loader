import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wechat_bill/services/wechat_bill_parser.dart';

void main() {
  test('parse sample october bill', () {
    final file = File('sample_data/微信支付账单_2025年10月_测试.xlsx');
    expect(file.existsSync(), isTrue);
    final rows = WechatBillParser().parseBytes(file.readAsBytesSync());
    expect(rows.length, 10);
  });
}
