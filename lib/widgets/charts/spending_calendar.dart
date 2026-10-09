import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The month as a calendar; a day's color deepens with what was spent.
/// Tapping a day selects it (the screen lists that day's entries).
class SpendingCalendar extends StatelessWidget {
  final DateTime month;
  final List<double> daily;
  final int? selectedDay;
  final ValueChanged<int> onSelect;

  /// Days after this one (today) are in the future and drawn faded.
  final int lastDay;

  const SpendingCalendar({
    super.key,
    required this.month,
    required this.daily,
    required this.selectedDay,
    required this.onSelect,
    required this.lastDay,
  });

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final leading = DateTime(month.year, month.month).weekday - 1; // Monday first
    final cells = leading + daily.length;
    final rows = (cells / 7).ceil();
    return Column(children: [
      Row(children: [
        for (final day in _weekdays)
          Expanded(
            child: Text(day,
                textAlign: TextAlign.center,
                style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ),
      ]),
      const SizedBox(height: Space.s),
      for (var row = 0; row < rows; row++)
        Row(children: [
          for (var col = 0; col < 7; col++) Expanded(child: _cell(context, row * 7 + col - leading + 1)),
        ]),
    ]);
  }

  Widget _cell(BuildContext context, int day) {
    if (day < 1 || day > daily.length) return const SizedBox(height: 44);
    return _DayCell(
      day: day,
      level: _level(daily[day - 1]),
      selected: day == selectedDay,
      future: day > lastDay,
      onTap: () => onSelect(day),
    );
  }

  /// 0 = nothing spent, 1–4 = quarters of the month's biggest day.
  int _level(double amount) {
    final top = daily.fold(0.0, max);
    if (amount <= 0 || top <= 0) return 0;
    return (amount / top * 4).ceil().clamp(1, 4);
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final int level;
  final bool selected;
  final bool future;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.level,
    required this.selected,
    required this.future,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const alphas = [0, 70, 120, 180, 255];
    final fill = future
        ? Colors.transparent
        : level == 0
            ? colors.surfaceContainerHighest
            : colors.primary.withAlpha(alphas[level]);
    final ink = level >= 3 ? colors.onPrimary : colors.onSurface;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.small),
          side: selected ? BorderSide(color: colors.onSurface, width: 2) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Corners.small),
          onTap: future ? null : onTap,
          child: SizedBox(
            height: 40,
            child: Center(
              child: Text('$day',
                  style: context.text.labelMedium?.copyWith(
                      color: future ? colors.onSurfaceVariant.withAlpha(90) : ink)),
            ),
          ),
        ),
      ),
    );
  }
}
