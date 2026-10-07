import '../models/bill_record.dart';
import '../models/merchant_category_rule.dart';
import '../models/spending_category.dart';

/// 根据商家规则、交易类型与对方名称自动分类
class CategoryClassifier {
  CategoryClassifier({List<MerchantCategoryRule> merchantRules = const []})
      : _merchantRules = List.of(merchantRules);

  List<MerchantCategoryRule> _merchantRules;

  void updateMerchantRules(List<MerchantCategoryRule> rules) {
    _merchantRules = List.of(rules);
  }

  BookCategory classify(ParsedBillRow row) {
    final fromRule = _classifyByMerchantRule(row);
    if (fromRule != null) return fromRule;

    if (row.flow == '收入') {
      return _classifyIncome(row);
    }
    return _classifyExpense(row);
  }

  BookCategory? _classifyByMerchantRule(ParsedBillRow row) {
    MerchantCategoryRule? best;
    for (final rule in _merchantRules) {
      if (!rule.matchesFlow(row.flow)) continue;
      if (!rule.matchesCounterparty(row.counterparty)) continue;
      if (best == null ||
          rule.merchantKeyword.length > best.merchantKeyword.length) {
        best = rule;
      }
    }
    return best?.category;
  }

  BookCategory classifyRecord(BillRecord record) {
    return classify(ParsedBillRow(
      date: record.date,
      transactionType: record.transactionType,
      counterparty: record.counterparty,
      flow: record.flow,
      amount: record.amount,
    ));
  }

  BookCategory _classifyIncome(ParsedBillRow row) {
    final blob = _blob(row);
    if (_containsAny(blob, ['工资', '薪资', '发薪'])) return BookCategory.salary;
    if (_containsAny(blob, ['退款', '退现'])) return BookCategory.otherIncome;
    if (_containsAny(blob, ['理财', '收益', '利息', '红包'])) {
      return BookCategory.investment;
    }
    if (_containsAny(blob, ['兼职', '劳务'])) return BookCategory.sideIncome;
    return BookCategory.otherIncome;
  }

  BookCategory _classifyExpense(ParsedBillRow row) {
    final blob = _blob(row);
    final type = row.transactionType;

    if (_containsAny(type, ['转账', '红包', '群收款'])) return BookCategory.social;
    if (_containsAny(type, ['充值', '缴费', '还款'])) return BookCategory.home;
    if (_containsAny(type, ['理财', '零钱通'])) return BookCategory.otherExpense;

    if (_containsAny(blob, [
      '美团',
      '饿了么',
      '肯德基',
      '麦当劳',
      '星巴克',
      '咖啡',
      '餐厅',
      '饭店',
      '外卖',
      '奶茶',
      '面',
      '饭',
      '餐',
      '食',
      '便利',
      '超市',
      '盒马',
    ])) {
      return BookCategory.food;
    }

    if (_containsAny(blob, [
      '地铁',
      '公交',
      '滴滴',
      '出租',
      '高铁',
      '火车',
      '机票',
      '加油',
      '停车',
      '交通',
      '出行',
      '哈啰',
      '高德',
    ])) {
      return BookCategory.transport;
    }

    if (_containsAny(blob, [
      '医院',
      '药店',
      '医药',
      '诊所',
      '体检',
      '健康',
    ])) {
      return BookCategory.medical;
    }

    if (_containsAny(blob, [
      'Steam',
      '游戏',
      '视频',
      '会员',
      '腾讯',
      '爱奇艺',
      'B站',
      '电影',
      'KTV',
    ])) {
      return BookCategory.entertainment;
    }

    if (_containsAny(blob, [
      '淘宝',
      '京东',
      '拼多多',
      '天猫',
      'UNIQLO',
      'HM',
      '商城',
      '购物',
      'App',
    ])) {
      return BookCategory.shopping;
    }

    if (_containsAny(blob, ['学校', '培训', '教育', '课程', '书店'])) {
      return BookCategory.education;
    }

    if (_containsAny(blob, ['水电', '物业', '房租', '宽带', '通信', '移动', '联通', '电信'])) {
      return BookCategory.home;
    }

    if (_containsAny(blob, ['办公', '打印', '文具'])) {
      return BookCategory.office;
    }

    return BookCategory.otherExpense;
  }

  String _blob(ParsedBillRow row) =>
      '${row.transactionType}${row.counterparty}'.toLowerCase();

  bool _containsAny(String haystack, List<String> needles) {
    for (final n in needles) {
      if (haystack.contains(n.toLowerCase())) return true;
    }
    return false;
  }
}
