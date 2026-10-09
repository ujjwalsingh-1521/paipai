import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../models/ledger_entry.dart';
import '../models/split_part.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import 'payment_details.dart';
import 'split_editor.dart';
import 'undo_delete.dart';

/// Split an existing expense, or change, unsplit or delete a split one.
Future<void> showSplitSheet(BuildContext context, LedgerEntry entry) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SplitSheet(entry: entry),
    );

class _SplitSheet extends ConsumerWidget {
  final LedgerEntry entry;
  const _SplitSheet({required this.entry});

  Expense get _lead => entry.expense!;

  /// Parts in the order they were made, so the first part stays "the rest".
  List<SplitPart> get _initial {
    if (!entry.isSplit) return [SplitPart(_lead.category, 0, note: _lead.notes)];
    final byId = [...entry.parts]..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
    return [for (final p in byId) SplitPart(p.category, p.amount, note: p.notes)];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    final payee = entry.payee;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          Space.xl, 0, Space.xl, Space.xl + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(payee == null ? 'Payment' : 'Paid to $payee', style: muted, textAlign: TextAlign.center),
        Text(formatMoney(entry.amount), style: context.text.displaySmall, textAlign: TextAlign.center),
        Text(DateFormat('EEEE, d MMM yyyy').format(entry.date), style: muted, textAlign: TextAlign.center),
        const SizedBox(height: Space.l),
        SplitEditor(
          total: entry.amount,
          initial: _initial,
          cancelLabel: entry.isSplit ? 'Close' : 'Cancel',
          onCancel: () => Navigator.pop(context),
          onSave: (parts) async {
            await ref.read(expenseProvider.notifier).saveSplit(_lead, parts);
            if (context.mounted) Navigator.pop(context);
          },
        ),
        if (entry.isSplit) _actions(context, ref),
        PaymentDetails(expenseId: _lead.splitId ?? _lead.id),
      ]),
    );
  }

  Widget _actions(BuildContext context, WidgetRef ref) {
    final splitId = _lead.splitId!;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s),
      child: Row(children: [
        TextButton.icon(
          onPressed: () async {
            await ref.read(expenseProvider.notifier).unsplit(splitId);
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.merge_rounded),
          label: Text('Unsplit (all ${_lead.category})'),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () async {
            // Start the delete (which reads `ref`) before the sheet closes.
            final deletion = deleteSplitWithUndo(ref, ScaffoldMessenger.of(context), splitId);
            Navigator.pop(context);
            await deletion;
          },
          style: TextButton.styleFrom(foregroundColor: context.colors.error),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Delete'),
        ),
      ]),
    );
  }
}
