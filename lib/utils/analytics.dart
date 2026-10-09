import '../models/category.dart';
import '../models/category_symbol.dart';
import '../models/expense.dart';
import 'package:intl/intl.dart';

import 'money.dart';

/// First day of the month [date] is in.
DateTime monthOf(DateTime date) => DateTime(date.year, date.month);

int daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

bool isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

List<Expense> expensesIn(List<Expense> all, DateTime month) =>
    all.where((e) => isSameMonth(e.date, month)).toList();

/// Spending on each day of [month] (index 0 = the 1st).
List<double> dailyTotals(List<Expense> all, DateTime month) {
  final totals = List<double>.filled(daysInMonth(month), 0);
  for (final e in expensesIn(all, month)) {
    totals[e.date.day - 1] = roundMoney(totals[e.date.day - 1] + e.amount);
  }
  return totals;
}

/// Running total of spending through [month] (index 0 = end of the 1st).
List<double> cumulativeTotals(List<Expense> all, DateTime month) {
  var running = 0.0;
  return [
    for (final day in dailyTotals(all, month)) running = roundMoney(running + day),
  ];
}

/// How this month's spending compares with last month's at the same point.
class MonthPace {
  final DateTime month;

  /// Days of [month] that have happened (the whole month once it's over).
  final int daysElapsed;
  final List<double> thisMonth;
  final List<double> lastMonth;

  const MonthPace._(this.month, this.daysElapsed, this.thisMonth, this.lastMonth);

  factory MonthPace.of(List<Expense> all, DateTime month, DateTime now) {
    final start = monthOf(month);
    final elapsed = isSameMonth(start, now) ? now.day : daysInMonth(start);
    return MonthPace._(
      start,
      elapsed,
      cumulativeTotals(all, start),
      cumulativeTotals(all, DateTime(start.year, start.month - 1)),
    );
  }

  DateTime get previousMonth => DateTime(month.year, month.month - 1);
  double get spent => thisMonth[daysElapsed - 1];
  double get lastMonthTotal => lastMonth.isEmpty ? 0 : lastMonth.last;

  /// Last month's spending by the same day (its last day if shorter).
  double get lastMonthSoFar =>
      lastMonth.isEmpty ? 0 : lastMonth[(daysElapsed - 1).clamp(0, lastMonth.length - 1)];

  /// Positive = spent more than by this day last month.
  double get difference => roundMoney(spent - lastMonthSoFar);
}

/// One category's share of a month's spending.
class CategoryTotal {
  final String name;
  final double amount;
  final double share;
  const CategoryTotal(this.name, this.amount, this.share);
}

/// Categories by amount spent, largest first.
List<CategoryTotal> categoryTotals(List<Expense> monthExpenses) {
  final sums = <String, double>{};
  for (final e in monthExpenses) {
    sums[e.category] = roundMoney((sums[e.category] ?? 0) + e.amount);
  }
  final total = sumMoney(sums.values);
  final list = [
    for (final entry in sums.entries)
      CategoryTotal(entry.key, entry.value, total == 0 ? 0 : entry.value / total),
  ];
  return list..sort((a, b) => b.amount.compareTo(a.amount));
}

ExpenseCategory findCategory(List<ExpenseCategory> cats, String name) {
  return cats.cast<ExpenseCategory?>().firstWhere(
          (c) => c!.name == name,
          orElse: () => null) ??
      ExpenseCategory(name: name, emoji: CategorySymbol.fallback, colorValue: 0xFF94A3B8);
}

/// "₹420 less than by this day in September", or why there's no comparison.
String paceSentence(MonthPace pace, DateTime now) {
  final previous = DateFormat('MMMM').format(pace.previousMonth);
  if (pace.lastMonthTotal == 0) return 'Nothing recorded in $previous to compare with';
  final when = isSameMonth(pace.month, now) ? 'by this day in $previous' : 'in $previous';
  final difference = pace.difference;
  if (difference == 0) return 'Same as $when';
  final word = difference > 0 ? 'more' : 'less';
  return '${formatMoney(difference.abs())} $word than $when';
}

/// The smallest round chart ceiling at or above [value]: 1, 2 or 5 times a
/// power of ten (₹8,523 → ₹10,000), so the half-way line is round too.
double niceCeiling(double value) {
  if (value <= 0) return 1000;
  var power = 1.0;
  while (power * 10 <= value) {
    power *= 10;
  }
  for (final step in const [1, 2, 5, 10]) {
    if (step * power >= value) return step * power;
  }
  return 10 * power;
}
