import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/ledger_entry.dart';
import '../providers/expense_provider.dart';
import '../providers/income_provider.dart';
import '../theme/app_theme.dart';
import '../utils/analytics.dart';
import '../utils/money.dart';
import '../widgets/entry_row.dart';
import '../widgets/month_switcher.dart';
import '../widgets/ui.dart';

enum _Show { all, spent, received }

/// Every entry of a month, grouped by day, newest first.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  DateTime _month = monthOf(DateTime.now());
  _Show _show = _Show.all;
  String? _label;

  @override
  Widget build(BuildContext context) {
    final all = LedgerEntry.merge(
      ref.watch(expenseProvider).valueOrNull ?? [],
      ref.watch(incomeProvider).valueOrNull ?? [],
    ).where((e) => isSameMonth(e.date, _month)).toList();
    final shown = all.where(_matches).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, 96), // room for the + button
      children: [
        MonthSwitcher(month: _month, onChanged: (m) => setState(() => _month = m)),
        const SizedBox(height: Space.s),
        _filters(),
        _labelChips(all),
        const SizedBox(height: Space.m),
        _Totals(entries: shown, category: _label),
        const SizedBox(height: Space.m),
        if (shown.isEmpty)
          const EmptyNote(
            icon: Icons.receipt_long_rounded,
            title: 'Nothing here yet',
            message: 'Payments you label and entries you add show up here.',
          )
        else
          for (final day in _byDay(shown)) ...[
            _DayHeader(entries: day, category: _label),
            GroupCard(children: [for (final entry in day) EntryRow(entry: entry)]),
            const SizedBox(height: Space.l),
          ],
      ],
    );
  }

  bool _matches(LedgerEntry entry) =>
      _matchesKind(entry) && (_label == null || entry.labels.contains(_label));

  Widget _filters() => SegmentedButton<_Show>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: _Show.all, label: Text('All')),
          ButtonSegment(value: _Show.spent, label: Text('Spent')),
          ButtonSegment(value: _Show.received, label: Text('Received')),
        ],
        selected: {_show},
        onSelectionChanged: (s) => setState(() {
          _show = s.first;
          _label = null;
        }),
      );

  /// Categories (and sources) used this month, to narrow the list.
  Widget _labelChips(List<LedgerEntry> monthEntries) {
    final labels = {
      for (final e in monthEntries)
        if (_matchesKind(e)) ...e.labels,
    }.toList()
      ..sort();
    if (labels.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: Space.s),
        children: [
          for (final label in labels)
            Padding(
              padding: const EdgeInsets.only(right: Space.s),
              child: FilterChip(
                label: Text(label),
                selected: _label == label,
                onSelected: (on) => setState(() => _label = on ? label : null),
              ),
            ),
        ],
      ),
    );
  }

  bool _matchesKind(LedgerEntry e) => switch (_show) {
        _Show.all => true,
        _Show.spent => !e.isIncome,
        _Show.received => e.isIncome,
      };

  static List<List<LedgerEntry>> _byDay(List<LedgerEntry> entries) {
    final days = <List<LedgerEntry>>[];
    for (final entry in entries) {
      final last = days.isEmpty ? null : days.last.first.date;
      final sameDay = last != null && DateUtils.isSameDay(last, entry.date);
      sameDay ? days.last.add(entry) : days.add([entry]);
    }
    return days;
  }
}

/// "Spent ₹1,589 · Received ₹0" for what's shown.
/// What [e] counts for in the totals: with a category filter on, only a
/// split payment's part in that category.
double _shownAmount(LedgerEntry e, String? category) =>
    category == null ? e.amount : e.amountIn(category);

class _Totals extends StatelessWidget {
  final List<LedgerEntry> entries;
  final String? category;
  const _Totals({required this.entries, required this.category});

  @override
  Widget build(BuildContext context) {
    final spent = sumMoney(entries.where((e) => !e.isIncome).map((e) => _shownAmount(e, category)));
    final received = sumMoney(entries.where((e) => e.isIncome).map((e) => _shownAmount(e, category)));
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xs),
      child: Text.rich(TextSpan(style: muted, children: [
        const TextSpan(text: 'Spent '),
        TextSpan(text: formatMoney(spent), style: TextStyle(color: context.colors.onSurface)),
        const TextSpan(text: '   ·   Received '),
        TextSpan(text: formatMoney(received), style: TextStyle(color: context.money.income)),
      ])),
    );
  }
}

/// "Today ........ ₹1,019 spent".
class _DayHeader extends StatelessWidget {
  final List<LedgerEntry> entries;
  final String? category;
  const _DayHeader({required this.entries, required this.category});

  @override
  Widget build(BuildContext context) {
    final spent = sumMoney(entries.where((e) => !e.isIncome).map((e) => _shownAmount(e, category)));
    final muted = context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xs, 0, Space.xs, Space.s),
      child: Row(children: [
        Expanded(child: Text(_dayName(entries.first.date), style: context.text.titleSmall)),
        if (spent > 0) Text('${formatMoney(spent)} spent', style: muted),
      ]),
    );
  }

  static String _dayName(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(date);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEEE, d MMM').format(date);
  }
}
