import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../models/ledger_entry.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/income_source_provider.dart';
import '../theme/app_theme.dart';
import '../utils/analytics.dart';
import '../utils/money.dart';
import 'category_icon.dart';
import 'edit_entry_sheet.dart';
import 'split_sheet.dart';
import 'undo_delete.dart';

/// One expense, income or split-payment line: icon, payee (or category),
/// category and time, amount. Tap to edit; swipe left to delete (with Undo).
/// A split payment (or one of its parts) always opens and deletes as a whole.
class EntryRow extends ConsumerWidget {
  final LedgerEntry entry;

  /// Show the date (lists not already grouped by day).
  final bool showDate;

  const EntryRow({super.key, required this.entry, this.showDate = false});

  int? get _splitId => entry.expense?.splitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payee = entry.payee;
    // A split's note belongs to one part, so it isn't shown on the row.
    final note = entry.isSplit ? null : entry.note;
    final when = showDate
        ? DateFormat('d MMM').format(entry.date)
        : DateFormat('h:mm a').format(entry.date);
    // Title: who was paid (else the category). The note gets its own line.
    final subtitle = payee == null && !entry.isSplit ? when : '${entry.label} · $when';
    final muted = context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant);
    return Dismissible(
      key: ValueKey('${entry.isIncome ? 'income' : 'expense'}_${entry.id}'),
      direction: DismissDirection.endToStart,
      background: _DeleteBackground(),
      onDismissed: (_) => _delete(ref, ScaffoldMessenger.of(context)),
      child: InkWell(
        onTap: () => _edit(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
          child: Row(children: [
            entry.isSplit ? const _SplitIcon() : _icon(ref),
            const SizedBox(width: Space.m + 2),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(payee ?? (entry.isSplit ? 'Split payment' : entry.label),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                if (entry.isSplit) _ShareBar(parts: entry.parts),
                if (note != null)
                  Text(note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted?.copyWith(fontStyle: FontStyle.italic)),
              ]),
            ),
            const SizedBox(width: Space.m),
            Text(
              entry.isIncome ? '+${formatMoney(entry.amount)}' : formatMoney(entry.amount),
              style: context.text.titleSmall?.copyWith(
                  color: entry.isIncome ? context.money.income : context.colors.onSurface),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _icon(WidgetRef ref) {
    final list = entry.isIncome
        ? ref.watch(incomeSourceProvider).valueOrNull ?? <ExpenseCategory>[]
        : ref.watch(categoryProvider).valueOrNull ?? <ExpenseCategory>[];
    final style = findCategory(list, entry.label);
    return CategoryIcon(symbol: style.emoji, color: style.color);
  }

  /// The whole split this row belongs to (a part shown on its own, e.g. in
  /// the Insights calendar, still edits as one payment).
  LedgerEntry _group(WidgetRef ref) {
    if (entry.isSplit || _splitId == null) return entry;
    final all = ref.read(expenseProvider).valueOrNull ?? <Expense>[];
    return LedgerEntry.split(all.where((e) => e.splitId == _splitId).toList());
  }

  void _edit(BuildContext context, WidgetRef ref) {
    if (_splitId != null) {
      showSplitSheet(context, _group(ref));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => entry.isIncome
          ? EditEntrySheet.income(entry.income!)
          : EditEntrySheet.expense(entry.expense!),
    );
  }

  Future<void> _delete(WidgetRef ref, ScaffoldMessengerState messenger) {
    if (_splitId != null) return deleteSplitWithUndo(ref, messenger, _splitId!);
    return entry.isIncome
        ? deleteIncomeWithUndo(ref, messenger, entry.income!)
        : deleteExpenseWithUndo(ref, messenger, entry.expense!);
  }
}

class _SplitIcon extends StatelessWidget {
  const _SplitIcon();

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 20,
        backgroundColor: context.colors.secondaryContainer,
        foregroundColor: context.colors.onSecondaryContainer,
        child: const Icon(Icons.call_split_rounded, size: 20),
      );
}

/// A thin bar showing how a split payment divides between its categories.
class _ShareBar extends ConsumerWidget {
  final List<Expense> parts;
  const _ShareBar({required this.parts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider).valueOrNull ?? <ExpenseCategory>[];
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs + 2, right: Space.xl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 4,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                flex: (parts[i].amount * 100).round().clamp(1, 1 << 30),
                child: ColoredBox(color: findCategory(categories, parts[i].category).color),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: context.colors.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.xl),
        child: Icon(Icons.delete_rounded, color: context.colors.onErrorContainer),
      );
}
