import 'package:flutter/material.dart';

import '../app.dart';

class StatsMonthlyBarPoint {
  StatsMonthlyBarPoint({
    required this.month,
    required this.monthLabel,
    required this.amount,
    required this.isFocused,
  });

  final DateTime month;
  final String monthLabel;
  final double amount;
  final bool isFocused;
}

/// 近六个月柱状对比（仿微信记账本「月度对比」）
class StatsMonthlyBarChart extends StatelessWidget {
  const StatsMonthlyBarChart({
    super.key,
    required this.points,
    this.title = '月度对比',
    this.chartHeight = 160,
    this.barWidth = 22,
    this.showAmounts = true,
    this.amountFontSize = 10,
    this.onMonthTap,
  });

  final List<StatsMonthlyBarPoint> points;
  final String title;
  final double chartHeight;
  final double barWidth;
  final bool showAmounts;
  final double amountFontSize;
  final ValueChanged<DateTime>? onMonthTap;

  static const _lightGreen = Color(0xFFB8E8CC);
  static const _labelGreen = Color(0xFF5CC48E);

  @override
  Widget build(BuildContext context) {
    final maxAmount = points.fold<double>(
      0,
      (prev, p) => p.amount > prev ? p.amount : prev,
    );
    final labelArea = showAmounts ? 28.0 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: chartHeight + labelArea + 28,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return CustomPaint(
                      painter: _GridPainter(
                        width: constraints.maxWidth,
                        lineCount: 4,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final p in points)
                            Expanded(
                              child: _BarColumn(
                                point: p,
                                maxAmount: maxAmount,
                                chartHeight: chartHeight,
                                barWidth: barWidth,
                                showAmount: showAmounts,
                                amountFontSize: amountFontSize,
                                onTap: onMonthTap == null
                                    ? null
                                    : () => onMonthTap!(p.month),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final p in points)
                    Expanded(
                      child: Text(
                        p.monthLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: points.length > 8 ? 10 : 12,
                          color: p.isFocused
                              ? WechatBillApp.wechatGreen
                              : Colors.grey.shade700,
                          fontWeight:
                              p.isFocused ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.point,
    required this.maxAmount,
    required this.chartHeight,
    required this.barWidth,
    required this.showAmount,
    required this.amountFontSize,
    this.onTap,
  });

  final StatsMonthlyBarPoint point;
  final double maxAmount;
  final double chartHeight;
  final double barWidth;
  final bool showAmount;
  final double amountFontSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = maxAmount > 0 ? point.amount / maxAmount : 0.0;
    final barHeight = maxAmount > 0
        ? (ratio * chartHeight).clamp(4.0, chartHeight)
        : 4.0;
    final barColor = point.isFocused
        ? WechatBillApp.wechatGreen
        : StatsMonthlyBarChart._lightGreen;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (showAmount)
            Text(
              '¥${point.amount.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: amountFontSize,
                color: StatsMonthlyBarChart._labelGreen,
                height: 1.2,
              ),
            ),
          if (showAmount) const SizedBox(height: 4),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: barWidth,
              height: barHeight,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.width, required this.lineCount});

  final double width;
  final int lineCount;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;
    for (var i = 0; i <= lineCount; i++) {
      final y = size.height * i / lineCount;
      canvas.drawLine(Offset(0, y), Offset(width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
