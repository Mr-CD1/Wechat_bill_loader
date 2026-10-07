import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'services/ledger_repository.dart';

class WechatBillApp extends StatelessWidget {
  const WechatBillApp({super.key});

  static const wechatGreen = Color(0xFF07C160);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LedgerRepository()..load(),
      child: MaterialApp(
        title: '记账本',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: wechatGreen,
            primary: wechatGreen,
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: wechatGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: wechatGreen,
            foregroundColor: Colors.white,
          ),
          useMaterial3: true,
        ),
        home: const HomeShell(),
      ),
    );
  }
}
