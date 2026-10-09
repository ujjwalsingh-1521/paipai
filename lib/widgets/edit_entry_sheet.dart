import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/ledger_entry.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/income_provider.dart';
import '../providers/income_source_provider.dart';
import '../theme/app_theme.dart';
import 'category_chip.dart';
import 'entry_fields.dart';
import 'payment_details.dart';
import 'split_sheet.dart';
import 'undo_delete.dart';

/// Edit or delete one expense or income entry.
class EditEntrySheet extends ConsumerStatefulWidget {
  final Expense? expense;
  final Income? income;

  const EditEntrySheet.expense(Expense this.expense, {super.key}) : income = null;
  const EditEntrySheet.income(Income this.income, {super.key}) : expense = null;

  @override
  ConsumerState<EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends ConsumerState<EditEntrySheet> {
  late final TextEditingController _amount;
  late final TextEditingController _payee;
  late final TextEditingController _notes;
  late String _label;
  late DateTime _date;
  bool _saving = false;

  bool get _isExpense => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final amount = widget.expense?.amount ?? widget.income!.amount;
    _amount = TextEditingController(text: amount.toStringAsFixed(2));
    _payee = TextEditingController(text: widget.expense?.payee ?? widget.income?.payee ?? '');
    _notes = TextEditingController(text: widget.expense?.notes ?? widget.income?.notes ?? '');
    _label = widget.expense?.category ?? widget.income!.source;
    _date = widget.expense?.date ?? widget.income!.date;
  }

  @override
  void dispose() {
    _amount.dispose();
    _payee.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0 || _saving) return;
    setState(() => _saving = true); // a second tap can't save twice
    final payee = textOrNull(_payee);
    final notes = textOrNull(_notes);
    if (_isExpense) {
      await ref.read(expenseProvider.notifier).updateExpense(Expense(
          id: widget.expense!.id, amount: amount, category: _label, date: _date, payee: payee, notes: notes));
    } else {
      await ref.read(incomeProvider.notifier).updateIncome(Income(
          id: widget.income!.id, amount: amount, source: _label, date: _date, payee: payee, notes: notes));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    // Start the delete (which reads `ref`) before the sheet is closed.
    final messenger = ScaffoldMessenger.of(context);
    final deletion = _isExpense
        ? deleteExpenseWithUndo(ref, messenger, widget.expense!)
        : deleteIncomeWithUndo(ref, messenger, widget.income!);
    Navigator.pop(context);
    await deletion;
  }

  Future<void> _pickDate() async {
    final picked = await pickEntryDate(context, _date);
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          Space.xl, 0, Space.xl, Space.xl + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_isExpense ? 'Edit Expense' : 'Edit Income',
              style: context.text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: Space.s),
          AmountField(controller: _amount),
          const SizedBox(height: Space.l),
          Text(_isExpense ? 'Category' : 'Source', style: context.text.titleSmall),
          const SizedBox(height: Space.s),
          _labelChips(),
          if (_isExpense) _splitButton(),
          const SizedBox(height: Space.l),
          EntryDateRow(date: _date, onTap: _pickDate, accent: context.colors.primary),
          const SizedBox(height: Space.m),
          PayeeAndNoteFields(payee: _payee, note: _notes, income: !_isExpense),
          PaymentDetails(expenseId: widget.expense?.id, incomeId: widget.income?.id),
          const SizedBox(height: Space.xl),
          _buttons(),
        ],
      ),
    );
  }

  /// Closes this sheet and opens the split screen for the same payment.
  Widget _splitButton() => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            final parent = Navigator.of(context).context;
            Navigator.pop(context);
            showSplitSheet(parent, LedgerEntry.expense(widget.expense!));
          },
          icon: const Icon(Icons.call_split_rounded),
          label: const Text('Split across categories'),
        ),
      );

  Widget _labelChips() {
    final List<ExpenseCategory> options = _isExpense
        ? ref.watch(categoryProvider).valueOrNull ?? []
        : ref.watch(incomeSourceProvider).valueOrNull ?? [];
    return Wrap(spacing: Space.s, runSpacing: Space.s, children: [
      for (final option in options)
        CategoryChip(
          emoji: option.emoji,
          label: option.name,
          color: option.color,
          selected: _label == option.name,
          onTap: () => setState(() => _label = option.name),
          compact: true,
        ),
    ]);
  }

  Widget _buttons() {
    final error = context.colors.error;
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _saving ? null : _delete,
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Delete'),
          style: OutlinedButton.styleFrom(
            foregroundColor: error,
            side: BorderSide(color: error.withAlpha(120)),
          ),
        ),
      ),
      const SizedBox(width: Space.m),
      Expanded(
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ),
    ]);
  }
}
