import 'package:intl/intl.dart';

import '../../models/budget.dart';
import '../../models/category.dart';
import '../../models/expense.dart';
import '../../models/pending_transaction.dart';
import '../../utils/analytics.dart';
import '../../utils/money.dart';
import '../capture/capture_alerts.dart';

/// Everything the home-screen widgets show, already worded and formatted,
/// so the Android side only lays it out (see PaiPaiWidgets.kt).
abstract final class WidgetSnapshot {
  static const maxPending = 20;
  static const maxCategories = 8;

  /// [pending] newest first; [buttons] holds each payment's two suggested
  /// categories (the same ones its notification shows).
  static Map<String, Object?> build({
    required List<PendingTransaction> pending,
    required Map<int, List<String>> buttons,
    required List<Expense> expenses,
    required List<ExpenseCategory> categories,
    required DateTime now,
    List<Budget> budgets = const [],
  }) {
    final pace = MonthPace.of(expenses, now, now);
    final hasSpending = pace.spent > 0 || pace.lastMonthTotal > 0;
    final totals = categoryTotals(expensesIn(expenses, monthOf(now)));
    final limits = {for (final b in budgetsIn(budgets, now)) b.category: b.amount!};
    final overall = limits[Budget.overall];
    return {
      'month': DateFormat('MMMM').format(now),
      'monthKey': '${now.year}-${now.month}',
      'pending': [for (final tx in pending.take(maxPending)) _payment(tx, buttons[tx.id] ?? const [])],
      'spent': formatMoney(pace.spent),
      if (overall != null) 'budget': _budgetLine(pace.spent, overall),
      'pace': hasSpending ? paceSentence(pace, now) : 'Your spending this month will show up here',
      'thisMonth': pace.thisMonth.take(pace.daysElapsed).toList(),
      'lastMonth': pace.lastMonthTotal > 0 ? pace.lastMonth : const <double>[],
      'days': pace.thisMonth.length,
      ..._axis(pace, now),
      'categories': [
        for (final total in totals.take(maxCategories))
          _category(total, findCategory(categories, total.name), limits[total.name]),
      ],
      // more[k]: everything from the k-th category on, as one "N more" row,
      // for when only k rows fit on the widget.
      'more': [for (var k = 0; k < totals.length; k++) _rest(totals.skip(k).toList())],
    };
  }

  /// The pace chart's scale: a round top (and its half) for the amount labels,
  /// and the first, middle and last day of the month under it.
  static Map<String, Object?> _axis(MonthPace pace, DateTime now) {
    final values = [...pace.thisMonth.take(pace.daysElapsed), if (pace.lastMonthTotal > 0) ...pace.lastMonth];
    final top = niceCeiling(values.fold(0.0, (highest, v) => v > highest ? v : highest));
    final month = DateFormat('MMM').format(now);
    final days = pace.thisMonth.length;
    return {
      'axisTop': top,
      'axisLabels': [formatMoneyCompact(top), formatMoneyCompact(top / 2), formatMoneyCompact(0)],
      'dayLabels': ['1 $month', '${(days + 1) ~/ 2}', '$days $month'],
    };
  }

  static Map<String, Object?> _payment(PendingTransaction tx, List<String> buttons) => {
        'id': tx.id,
        'title': AlertText.reviewTitle(tx),
        'time': DateFormat('d MMM · h:mm a').format(tx.detectedAt),
        'buttons': buttons,
      };

  static Map<String, Object?> _rest(List<CategoryTotal> rest) {
    final percent = (rest.fold(0.0, (sum, t) => sum + t.share) * 100).round();
    return {
      'name': '${rest.length} more',
      'amount': formatMoney(sumMoney(rest.map((t) => t.amount))),
      'percent': '$percent%',
    };
  }

  /// "₹17,707 left of ₹25,000", or "₹1,200 over ₹25,000".
  static String _budgetLine(double spent, double limit) => spent > limit
      ? '${formatMoney(spent - limit)} over ${formatMoney(limit)}'
      : '${formatMoney(limit - spent)} left of ${formatMoney(limit)}';

  /// A category with a budget adds it ("₹6K"); a wide widget shows "₹4,200 / ₹6K".
  static Map<String, Object?> _category(CategoryTotal total, ExpenseCategory category, double? limit) {
    final percent = (total.share * 100).round();
    return {
      'name': total.name,
      'amount': formatMoney(total.amount),
      if (limit != null) 'budget': formatMoneyCompact(limit),
      'percent': percent < 1 ? '<1%' : '$percent%',
      'share': total.share,
      'color': category.colorValue,
    };
  }
}
