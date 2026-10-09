import 'package:intl/intl.dart';

import '../models/budget.dart';
import '../models/expense.dart';
import 'analytics.dart';
import 'money.dart';

enum BudgetPace { onTrack, ahead, over }

/// How one budget stands in one month.
class BudgetStatus {
  final Budget budget;
  final double spent;

  /// Days of the month that have passed (all of them for a past month).
  final int daysElapsed;
  final int days;
  final DateTime month;

  const BudgetStatus({
    required this.budget,
    required this.spent,
    required this.daysElapsed,
    required this.days,
    required this.month,
  });

  /// [monthExpenses] are that month's expense rows (split parts included,
  /// each in its own category).
  factory BudgetStatus.of(Budget budget, List<Expense> monthExpenses, DateTime month, DateTime now) {
    final counted = budget.isOverall ? monthExpenses : monthExpenses.where((e) => e.category == budget.category);
    final days = daysInMonth(month);
    final elapsed = isSameMonth(month, now) ? now.day : (month.isAfter(now) ? 0 : days);
    return BudgetStatus(
      budget: budget,
      spent: sumMoney(counted.map((e) => e.amount)),
      daysElapsed: elapsed,
      days: days,
      month: monthOf(month),
    );
  }

  double get limit => budget.amount ?? 0;
  double get left => roundMoney(limit - spent);
  double get used => limit <= 0 ? 0 : spent / limit;
  int get daysLeft => days - daysElapsed;
  bool get isFinished => daysElapsed >= days;

  /// Where an even pace would be by today, as a share of the month (0–1).
  double get evenPaceShare => days == 0 ? 0 : daysElapsed / days;

  /// How much more than an even pace has been spent by today.
  double get aheadOfPace => spent - limit * evenPaceShare;

  /// The month's total if spending keeps its average daily rate.
  double get projected => daysElapsed == 0 ? spent : spent / daysElapsed * days;

  BudgetPace get pace {
    if (spent > limit) return BudgetPace.over;
    if (!isFinished && aheadOfPace > 0) return BudgetPace.ahead;
    return BudgetPace.onTrack;
  }
}

/// Which alert level [status] has reached: 0 none, 1 first warning,
/// 2 second warning, 3 over budget.
int budgetLevel(BudgetStatus status, BudgetAlertSettings settings) {
  if (status.spent > status.limit) return 3;
  final percent = status.used * 100;
  if (percent >= settings.second) return 2;
  if (percent >= settings.first) return 1;
  return 0;
}

/// Wording for budgets, kept separate so it can be tested.
abstract final class BudgetText {
  static String name(Budget budget, DateTime month) =>
      budget.isOverall ? '${DateFormat('MMMM').format(month)} budget' : budget.category;

  /// "29% used · 26 days left · on track".
  static String statusLine(BudgetStatus status) {
    final percent = (status.used * 100).round();
    switch (status.pace) {
      case BudgetPace.over:
        // The amount over is already the card's headline.
        return status.isFinished ? '$percent% used' : '$percent% used · ${_daysLeft(status.daysLeft)}';
      case BudgetPace.ahead:
        // Not a month-end projection: early on, one big payment would make
        // that look far worse than it is.
        return '$percent% used · ${formatMoney(status.aheadOfPace.roundToDouble())} ahead of pace';
      case BudgetPace.onTrack:
        if (status.isFinished) return '$percent% used';
        return '$percent% used · ${_daysLeft(status.daysLeft)} · on track';
    }
  }

  static String alertTitle(Budget budget, DateTime month, int level, BudgetAlertSettings settings) {
    if (level == 3) {
      return budget.isOverall ? "You're over your ${name(budget, month)}" : '${budget.category} is over budget';
    }
    final percent = level == 2 ? settings.second : settings.first;
    return budget.isOverall
        ? '$percent% of your ${name(budget, month)} used'
        : '${budget.category}: $percent% of budget used';
  }

  /// "₹20,000 of ₹25,000 · 9 days left" or "₹26,100 of ₹25,000 · ₹1,100 over".
  static String alertBody(BudgetStatus status) {
    final amounts = '${formatMoney(status.spent)} of ${formatMoney(status.limit)}';
    if (status.spent > status.limit) return '$amounts · ${formatMoney(-status.left)} over';
    return '$amounts · ${_daysLeft(status.daysLeft)}';
  }

  static String _daysLeft(int days) => days == 1 ? '1 day left' : '$days days left';
}
