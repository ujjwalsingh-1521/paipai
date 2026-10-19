import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/balance_start.dart';
import '../models/expense.dart';
import '../models/ledger_entry.dart';
import '../models/pending_transaction.dart';
import '../providers/balance_provider.dart';
import 'pending_transactions_screen.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/income_provider.dart';
import '../providers/pending_transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/analytics.dart';
import '../utils/budgets.dart';
import '../utils/money.dart';
import '../widgets/balance_sheet.dart';
import '../widgets/budget_widgets.dart';
import '../widgets/charts/pace_chart.dart';
import '../widgets/entry_row.dart';
import '../widgets/payment_review_sheet.dart';
import '../widgets/ui.dart';
import 'budgets_screen.dart';
import 'insights_screen.dart';

/// Balance, payments waiting for a label, this month's pace, latest entries.
class HomeScreen extends ConsumerWidget {
  /// Switches to the Activity tab.
  final VoidCallback onSeeAll;

  const HomeScreen({super.key, required this.onSeeAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(expenseProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load your entries: $e')),
          data: (expenses) => _content(context, ref, expenses),
        );
  }

  Widget _content(BuildContext context, WidgetRef ref, List<Expense> expenses) {
    final income = ref.watch(incomeProvider).valueOrNull ?? [];
    final pending = ref.watch(pendingTransactionProvider).valueOrNull ?? [];
    final entries = LedgerEntry.merge(expenses, income);
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, 96), // room for the + button
      children: [
        _BalanceHero(
          start: ref.watch(balanceStartProvider).valueOrNull,
          entries: entries,
          // Raw lists: a split payment's row holds only its first part.
          balance: (start) =>
              ref.watch(balanceProvider).valueOrNull ?? start.currentBalance(expenses, income),
          now: now,
        ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: Space.m),
          _ReviewBanner(pending: pending),
        ],
        ..._budget(context, ref, expenses, pending, now),
        const SizedBox(height: Space.m),
        _PaceCard(pace: MonthPace.of(expenses, now, now), now: now),
        const SizedBox(height: Space.l),
        SectionHeader('Recent', actionLabel: entries.isEmpty ? null : 'See all', onAction: onSeeAll),
        GroupCard(children: [
          if (entries.isEmpty)
            const EmptyNote(
              icon: Icons.receipt_long_rounded,
              title: 'No entries yet',
              message: 'Tap + to add one, or turn on payment auto-capture in Settings.',
            )
          else
            for (final entry in entries.take(5)) EntryRow(entry: entry, showDate: true),
        ]),
      ],
    );
  }
}

/// This month's budget card, or (with no budget at all) a prompt to set one.
List<Widget> _budget(
    BuildContext context, WidgetRef ref, List<Expense> expenses, List<PendingTransaction> pending, DateTime now) {
  final data = ref.watch(budgetProvider).valueOrNull;
  if (data == null) return const [];
  final overall = data.overallIn(now);
  if (overall == null) {
    if (data.activeIn(now).isNotEmpty || data.promptDismissed) return const [];
    return [const SizedBox(height: Space.m), const _BudgetPrompt()];
  }
  final status = BudgetStatus.of(overall, expensesIn(expenses, monthOf(now)), now, now);
  final waiting = sumMoney(pending.where((tx) => tx.isDebit).map((tx) => tx.amount));
  return [
    const SizedBox(height: Space.m),
    BudgetCard(
      status: status,
      title: BudgetText.name(overall, now),
      waiting: waiting,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InsightsScreen())),
    ),
  ];
}

/// "Set a monthly budget", until the user sets one or closes this.
class _BudgetPrompt extends ConsumerWidget {
  const _BudgetPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(Space.l, Space.xs, Space.xs, Space.xs),
        leading: CircleAvatar(
          backgroundColor: context.colors.secondaryContainer,
          foregroundColor: context.colors.onSecondaryContainer,
          child: const Icon(Icons.savings_rounded, size: 20),
        ),
        title: Text('Set a monthly budget', style: context.text.titleSmall),
        subtitle: Text("See what's left and get an alert before it runs out",
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
        trailing: IconButton(
          tooltip: 'Not now',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => ref.read(budgetProvider.notifier).dismissPrompt(),
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetsScreen())),
      ),
    );
  }
}

/// The bank balance, with this month's money in and out.
class _BalanceHero extends StatelessWidget {
  final BalanceStart? start;
  final List<LedgerEntry> entries;
  final double Function(BalanceStart start) balance;
  final DateTime now;

  const _BalanceHero({required this.start, required this.entries, required this.balance, required this.now});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final month = entries.where((e) => isSameMonth(e.date, now));
    final spent = sumMoney(month.where((e) => !e.isIncome).map((e) => e.amount));
    final received = sumMoney(month.where((e) => e.isIncome).map((e) => e.amount));
    return Material(
      color: colors.primaryContainer,
      borderRadius: BorderRadius.circular(Corners.extraLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showBalanceSheet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.l + 4, Space.xl, Space.l + 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bank balance', style: _onHero(context, context.text.labelLarge, 0.8)),
            const SizedBox(height: Space.xs),
            Text(start == null ? 'Set your balance' : formatMoney(balance(start!)),
                style: _onHero(context, start == null ? context.text.headlineMedium : context.text.displayMedium)),
            const SizedBox(height: Space.xs),
            Text(_caption(), style: _onHero(context, context.text.bodySmall, 0.8)),
            const SizedBox(height: Space.l),
            Wrap(spacing: Space.s, runSpacing: Space.s, children: [
              _Pill('Spent ${formatMoney(spent)} in ${DateFormat('MMM').format(now)}'),
              _Pill('In ${formatMoney(received)}'),
            ]),
          ]),
        ),
      ),
    );
  }


  String _caption() => start == null
      ? 'Tell PaiPai once; it keeps it up to date from your entries'
      : 'Kept up to date since ${DateFormat('d MMM').format(start!.setAt)} · tap to correct';

  static TextStyle? _onHero(BuildContext context, TextStyle? style, [double opacity = 1]) =>
      style?.copyWith(color: context.colors.onPrimaryContainer.withValues(alpha: opacity));
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.xs + 2),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: context.text.labelLarge?.copyWith(color: context.colors.onSurface)),
    );
  }
}

/// "1 payment to label · ₹899 Blinkit" → the review flow.
class _ReviewBanner extends ConsumerWidget {
  final List<PendingTransaction> pending;
  const _ReviewBanner({required this.pending});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final count = pending.length;
    final first = pending.first;
    final detail = count == 1
        ? '${formatMoney(first.amount)}${first.merchant == null ? '' : ' · ${first.merchant}'}'
        : count > _listFrom
            ? 'Tap to see them all'
            : 'Tap to go through them one by one';
    return Material(
      color: colors.tertiaryContainer,
      borderRadius: BorderRadius.circular(Corners.large),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(Space.l, Space.xs, Space.s, Space.xs),
        leading: Icon(Icons.label_important_rounded, color: colors.onTertiaryContainer),
        title: Text(count == 1 ? '1 payment to label' : '$count payments to label',
            style: context.text.titleSmall?.copyWith(color: colors.onTertiaryContainer)),
        subtitle: Text(detail, style: context.text.bodySmall?.copyWith(color: colors.onTertiaryContainer)),
        trailing: Icon(Icons.chevron_right_rounded, color: colors.onTertiaryContainer),
        onTap: () => count > _listFrom
            ? Navigator.push(
                context, MaterialPageRoute(builder: (_) => const PendingTransactionsScreen()))
            : reviewPendingPayments(context, ref),
      ),
    );
  }

  /// More than this (say, after an SMS import) opens the list first.
  static const _listFrom = 5;
}

/// This month so far against last month; opens Insights.
class _PaceCard extends StatelessWidget {
  final MonthPace pace;
  final DateTime now;

  const _PaceCard({required this.pace, required this.now});

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    final nothingYet = pace.spent == 0 && pace.lastMonthTotal == 0;
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InsightsScreen())),
        child: Padding(
          padding: const EdgeInsets.all(Space.l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${DateFormat('MMMM').format(now)} so far', style: context.text.titleMedium)),
              Text('Insights', style: context.text.labelLarge?.copyWith(color: context.colors.primary)),
              Icon(Icons.chevron_right_rounded, color: context.colors.primary),
            ]),
            const SizedBox(height: Space.xs),
            Text(formatMoney(pace.spent), style: context.text.headlineMedium),
            Text(nothingYet ? 'Your spending this month will show up here' : paceSentence(pace, now),
                style: muted),
            if (!nothingYet) ...[
              const SizedBox(height: Space.m),
              PaceChart(pace: pace, compact: true),
            ],
          ]),
        ),
      ),
    );
  }
}
