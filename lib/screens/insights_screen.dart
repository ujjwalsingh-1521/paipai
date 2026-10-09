import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/budget.dart';
import '../models/expense.dart';
import '../models/ledger_entry.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/analytics.dart';
import '../utils/budgets.dart';
import '../utils/money.dart';
import '../widgets/budget_widgets.dart';
import '../widgets/charts/category_breakdown.dart';
import '../widgets/charts/pace_chart.dart';
import '../widgets/charts/spending_calendar.dart';
import '../widgets/entry_row.dart';
import '../widgets/month_switcher.dart';
import '../widgets/ui.dart';

/// Every chart for one month: pace vs last month, where the money went,
/// and a calendar of spending days.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  DateTime _month = monthOf(DateTime.now());
  int? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expenseProvider).valueOrNull ?? [];
    final now = DateTime.now();
    final monthExpenses = expensesIn(expenses, _month);
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.xxl),
        children: [
          MonthSwitcher(
            month: _month,
            onChanged: (month) => setState(() {
              _month = month;
              _selectedDay = null;
            }),
          ),
          const SizedBox(height: Space.s),
          ..._budgetCard(monthExpenses, now),
          _paceCard(MonthPace.of(expenses, _month, now), now),
          const SizedBox(height: Space.l),
          _categoriesCard(monthExpenses),
          const SizedBox(height: Space.l),
          _calendarCard(expenses, monthExpenses, now),
        ],
      ),
    );
  }

  Widget _paceCard(MonthPace pace, DateTime now) => GroupCard(
        padding: const EdgeInsets.all(Space.l),
        children: [
          Text('Spent', style: _muted(context)),
          Text(formatMoney(pace.spent), style: context.text.headlineLarge),
          const SizedBox(height: Space.xs),
          Text(paceSentence(pace, now), style: _muted(context)),
          const SizedBox(height: Space.l),
          PaceChart(pace: pace),
          const SizedBox(height: Space.s),
          _Legend(month: pace.month, previous: pace.lastMonthTotal > 0 ? pace.previousMonth : null),
        ],
      );

  /// The monthly budget as it stood in the shown month.
  List<Widget> _budgetCard(List<Expense> monthExpenses, DateTime now) {
    final overall = ref.watch(budgetProvider).valueOrNull?.overallIn(_month);
    if (overall == null) return const [];
    return [
      BudgetCard(status: BudgetStatus.of(overall, monthExpenses, _month, now), title: BudgetText.name(overall, _month)),
      const SizedBox(height: Space.l),
    ];
  }

  Widget _categoriesCard(List<Expense> monthExpenses) {
    final totals = categoryTotals(monthExpenses);
    final categories = ref.watch(categoryProvider).valueOrNull ?? [];
    final now = DateTime.now();
    final budgets = {
      for (final b in ref.watch(budgetProvider).valueOrNull?.activeIn(_month) ?? const <Budget>[])
        if (!b.isOverall) b.category: BudgetStatus.of(b, monthExpenses, _month, now),
    };
    return GroupCard(
      padding: const EdgeInsets.all(Space.l),
      children: [
        Text('Where it went', style: context.text.titleMedium),
        const SizedBox(height: Space.m),
        if (totals.isEmpty)
          Text('No spending this month yet.', style: _muted(context))
        else
          CategoryBreakdown(totals: totals, categories: categories, budgets: budgets),
      ],
    );
  }

  Widget _calendarCard(List<Expense> all, List<Expense> monthExpenses, DateTime now) {
    final lastDay = isSameMonth(_month, now) ? now.day : daysInMonth(_month);
    final day = _selectedDay;
    // No card padding: a selected day's entry rows run edge to edge.
    return GroupCard(children: [
      Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Spending calendar', style: context.text.titleMedium),
          Text('Darker days had more spending. Tap a day to see it.', style: _muted(context)),
          const SizedBox(height: Space.m),
          SpendingCalendar(
            month: _month,
            daily: dailyTotals(all, _month),
            selectedDay: day,
            lastDay: lastDay,
            onSelect: (tapped) => setState(() => _selectedDay = day == tapped ? null : tapped),
          ),
          if (day != null) _dayHeader(monthExpenses, day),
        ]),
      ),
      if (day != null)
        for (final e in monthExpenses)
          if (e.date.day == day) EntryRow(entry: LedgerEntry.expense(e)),
      if (day != null) const SizedBox(height: Space.s),
    ]);
  }

  Widget _dayHeader(List<Expense> monthExpenses, int day) {
    final spent = monthExpenses.where((e) => e.date.day == day).map((e) => e.amount);
    final date = DateTime(_month.year, _month.month, day);
    return Padding(
      padding: const EdgeInsets.only(top: Space.l),
      child: Row(children: [
        Expanded(child: Text(DateFormat('EEEE, d MMM').format(date), style: context.text.titleSmall)),
        Text(spent.isEmpty ? 'Nothing spent' : formatMoney(sumMoney(spent)), style: context.text.titleSmall),
      ]),
    );
  }

  TextStyle? _muted(BuildContext context) =>
      context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
}

class _Legend extends StatelessWidget {
  final DateTime month;

  /// Null when last month has no spending (its line isn't drawn).
  final DateTime? previous;

  const _Legend({required this.month, required this.previous});

  @override
  Widget build(BuildContext context) {
    final name = DateFormat('MMMM');
    final style = context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant);
    Widget key(Color color, String label, {bool dashed = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 16,
            height: 3,
            decoration: BoxDecoration(
              color: dashed ? null : color,
              border: dashed ? Border(top: BorderSide(color: color, width: 2)) : null,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: Space.s - 2),
          Text(label, style: style),
        ]);
    return Wrap(spacing: Space.l, children: [
      key(context.colors.primary, name.format(month)),
      if (previous != null)
        key(context.colors.onSurfaceVariant.withAlpha(110), name.format(previous!), dashed: true),
    ]);
  }
}
