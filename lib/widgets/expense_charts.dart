import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../models/expense_category.dart';
import '../utils/currency_utils.dart';
import '../theme/app_theme.dart';

const categoryColors = [
  AppTheme.primary,
  Color(0xFF7274DA),
  Color(0xFFE3A13D),
  Color(0xFF5C8ED6),
  Color(0xFFDD7896),
];

class ExpenseCharts extends StatefulWidget {
  final List<Expense> expenses;
  const ExpenseCharts({super.key, required this.expenses});
  @override
  State<ExpenseCharts> createState() => _ExpenseChartsState();
}

class _ExpenseChartsState extends State<ExpenseCharts>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  int? _category;
  int? _day;
  @override
  void didUpdateWidget(ExpenseCharts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expenses != widget.expenses) {
      _animation.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totals = List<int>.filled(5, 0);
    final weekly = List<int>.filled(7, 0);
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    for (final expense in widget.expenses) {
      totals[expense.category.index] += expense.amount;
      final date = DateTime(
        expense.transactionDate.year,
        expense.transactionDate.month,
        expense.transactionDate.day,
      );
      final index = date.difference(monday).inDays;
      if (index >= 0 && index < 7) {
        weekly[index] += expense.amount;
      }
    }
    final sum = totals.fold(0, (a, b) => a + b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tổng chi tiêu • ${CurrencyUtils.formatVnd(sum)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: LayoutBuilder(
                  builder: (_, constraints) => GestureDetector(
                    onTapDown: (event) {
                      if (sum == 0) {
                        return;
                      }
                      final delta =
                          event.localPosition -
                          Offset(
                            constraints.maxWidth / 2,
                            constraints.maxHeight / 2,
                          );
                      if (delta.distance < 56 || delta.distance > 94) {
                        return;
                      }
                      final angle =
                          (math.atan2(delta.dy, delta.dx) +
                              math.pi / 2 +
                              2 * math.pi) %
                          (2 * math.pi);
                      var end = 0.0;
                      for (var i = 0; i < totals.length; i++) {
                        end += totals[i] / sum * 2 * math.pi;
                        if (angle < end) {
                          setState(() => _category = i);
                          break;
                        }
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (_, child) => CustomPaint(
                        painter: DonutPainter(
                          totals,
                          Curves.easeOutCubic.transform(_animation.value),
                          _category,
                        ),
                        child: Center(
                          child: Text(
                            sum == 0
                                ? 'Chưa có dữ liệu'
                                : _category == null
                                ? 'Chạm để xem'
                                : '${ExpenseCategory.values[_category!].label}\n${(totals[_category!] / sum * 100).toStringAsFixed(1)}%',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Wrap(
              spacing: 12,
              children: List.generate(
                5,
                (i) => TextButton(
                  onPressed: () => setState(() => _category = i),
                  child: Text(
                    '${ExpenseCategory.values[i].label}: ${CurrencyUtils.formatVnd(totals[i])}',
                    style: TextStyle(color: categoryColors[i]),
                  ),
                ),
              ),
            ),
            const Divider(),
            Text(
              'Chi tiêu tuần này (T2–CN)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_day != null)
              Text(
                '${['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][_day!]}: ${CurrencyUtils.formatVnd(weekly[_day!])}',
              ),
            SizedBox(
              height: 180,
              child: LayoutBuilder(
                builder: (_, constraints) => GestureDetector(
                  onTapDown: (event) => setState(
                    () => _day =
                        (event.localPosition.dx / (constraints.maxWidth / 7))
                            .floor()
                            .clamp(0, 6),
                  ),
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (_, child) => CustomPaint(
                      size: constraints.biggest,
                      painter: WeeklyPainter(
                        weekly,
                        Curves.easeOutCubic.transform(_animation.value),
                        _day,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DonutPainter extends CustomPainter {
  final List<int> totals;
  final double progress;
  final int? selected;
  DonutPainter(this.totals, this.progress, this.selected);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: 75);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30;
    canvas.drawCircle(center, 75, paint..color = Colors.grey.shade200);
    final sum = totals.fold(0, (a, b) => a + b);
    if (sum == 0) {
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < totals.length; i++) {
      final sweep = totals[i] / sum * math.pi * 2 * progress;
      paint
        ..color = categoryColors[i]
        ..strokeWidth = selected == i ? 36 : 30;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(DonutPainter oldDelegate) => true;
}

class WeeklyPainter extends CustomPainter {
  final List<int> values;
  final double progress;
  final int? selected;
  WeeklyPainter(this.values, this.progress, this.selected);
  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.reduce(math.max);
    final top = 28.0;
    final baseline = size.height - 25;
    final step = size.width / 7;
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()..color = Colors.grey,
    );
    for (var i = 0; i < 7; i++) {
      final height = maxValue == 0
          ? 0.0
          : values[i] / maxValue * (baseline - top) * progress;
      final rect = Rect.fromLTWH(
        i * step + step * .2,
        baseline - height,
        step * .6,
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()
          ..color = selected == i ? const Color(0xFFE3A13D) : AppTheme.primary,
      );
      void label(String text, double y, double fontSize) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(color: Colors.black87, fontSize: fontSize),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: step);
        painter.paint(canvas, Offset(i * step + (step - painter.width) / 2, y));
      }

      label(['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][i], baseline + 6, 12);
      if (values[i] > 0) {
        label(
          values[i] >= 1000000
              ? '${(values[i] / 1000000).toStringAsFixed(1)}tr'
              : '${(values[i] / 1000).toStringAsFixed(0)}k',
          baseline - height - 20,
          10,
        );
      }
    }
  }

  @override
  bool shouldRepaint(WeeklyPainter oldDelegate) => true;
}
