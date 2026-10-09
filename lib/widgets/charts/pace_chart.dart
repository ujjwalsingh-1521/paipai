import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../utils/analytics.dart';
import '../../utils/money.dart';

/// "Month so far vs last month": this month's running total (solid, up to
/// today) over last month's (dashed). Above the dashed line = spending
/// faster than last month. [compact] is the Home version: no axis labels
/// or touch.
class PaceChart extends StatelessWidget {
  final MonthPace pace;
  final bool compact;

  const PaceChart({super.key, required this.pace, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = max(pace.thisMonth.length, pace.lastMonth.length);
    final top = [...pace.thisMonth.take(pace.daysElapsed), ...pace.lastMonth].fold(0.0, max);
    return SizedBox(
      height: compact ? 112 : 200,
      child: LineChart(LineChartData(
        minX: 1,
        maxX: days.toDouble(),
        minY: 0,
        maxY: top == 0 ? 1000 : top * 1.15,
        gridData: FlGridData(
          show: !compact,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: colors.outlineVariant, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: compact ? const FlTitlesData(show: false) : _titles(context, days),
        lineTouchData: compact ? const LineTouchData(enabled: false) : _touch(context),
        // No dashed line when last month has nothing to compare with.
        lineBarsData: [
          pace.lastMonthTotal > 0 ? _lastMonthLine(colors) : LineChartBarData(spots: const []),
          _thisMonthLine(colors),
        ],
      )),
    );
  }

  LineChartBarData _thisMonthLine(ColorScheme colors) {
    final spots = [
      for (var day = 1; day <= pace.daysElapsed; day++) FlSpot(day.toDouble(), pace.thisMonth[day - 1]),
    ];
    return LineChartBarData(
      spots: spots,
      color: colors.primary,
      barWidth: 3,
      isCurved: false,
      isStrokeCapRound: true,
      // A dot only on today's point.
      dotData: FlDotData(
        checkToShowDot: (spot, _) => spot.x == pace.daysElapsed,
        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
            radius: 5, color: colors.primary, strokeWidth: 2, strokeColor: colors.surface),
      ),
      belowBarData: BarAreaData(show: true, color: colors.primary.withAlpha(36)),
    );
  }

  LineChartBarData _lastMonthLine(ColorScheme colors) => LineChartBarData(
        spots: [
          for (var day = 1; day <= pace.lastMonth.length; day++)
            FlSpot(day.toDouble(), pace.lastMonth[day - 1]),
        ],
        color: colors.onSurfaceVariant.withAlpha(110),
        barWidth: 2,
        dashArray: const [5, 5],
        dotData: const FlDotData(show: false),
      );

  FlTitlesData _titles(BuildContext context, int days) {
    final style = context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant);
    const none = AxisTitles(sideTitles: SideTitles(showTitles: false));
    return FlTitlesData(
      topTitles: none,
      leftTitles: none,
      rightTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 52,
          getTitlesWidget: (value, meta) => value == meta.max
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(left: Space.s),
                  child: Text(formatMoneyCompact(value), style: style),
                ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          interval: 1,
          getTitlesWidget: (value, _) {
            final day = value.toInt();
            final show = day == 1 || day == 15 || day == days;
            return show
                ? Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Text('$day', style: style),
                  )
                : const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  LineTouchData _touch(BuildContext context) {
    final month = DateFormat('MMM');
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => context.colors.inverseSurface,
        getTooltipItems: (spots) => [
          for (final spot in spots)
            LineTooltipItem(
              '${spot.x.toInt()} ${month.format(spot.barIndex == 1 ? pace.month : pace.previousMonth)}'
              ': ${formatMoney(spot.y)}',
              context.text.labelMedium!.copyWith(color: context.colors.onInverseSurface),
            ),
        ],
      ),
    );
  }
}

