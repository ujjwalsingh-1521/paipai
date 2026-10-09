import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../utils/analytics.dart';

/// "‹  October 2026  ›". Can't go past the current month.
class MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  const MonthSwitcher({super.key, required this.month, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isCurrent = isSameMonth(month, DateTime.now());
    return Row(children: [
      IconButton(
        tooltip: 'Previous month',
        icon: const Icon(Icons.chevron_left_rounded),
        onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
      ),
      Expanded(
        child: Text(DateFormat('MMMM yyyy').format(month),
            textAlign: TextAlign.center, style: context.text.titleMedium),
      ),
      IconButton(
        tooltip: 'Next month',
        icon: const Icon(Icons.chevron_right_rounded),
        onPressed: isCurrent ? null : () => onChanged(DateTime(month.year, month.month + 1)),
      ),
    ]);
  }
}
