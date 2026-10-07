import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wechat_bill/app.dart';

void main() {
  testWidgets('App smoke', (tester) async {
    await tester.pumpWidget(const WechatBillApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
