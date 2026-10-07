# 微信记账（Wechat_bill）

项目根目录即 Flutter 应用，并附带 Python 账单解析脚本用于桌面调试。

## 功能

- 导入微信支付导出的 **`.xlsx`** 账单，自动记账与分类
- 按月查看明细与支出统计（参考微信记账本）

## Flutter 应用

```bash
# 在项目根目录
flutter pub get
flutter run
```

## Python 脚本（可选）

```bash
pip install -r requirements.txt
python wechat_bill_parser.py "账单.xlsx"
```

## 目录

| 路径 | 说明 |
|------|------|
| `lib/` | Flutter 源码 |
| `wechat_bill_parser.py` | 与 App 内解析逻辑对应的命令行工具 |
| `android/` / `windows/` | 平台工程 |
