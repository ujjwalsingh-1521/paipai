import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/split_part.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/income_provider.dart';
import '../providers/income_source_provider.dart';
import '../theme/app_theme.dart';
import 'category_chip.dart';
import 'category_sheet.dart';
import 'split_editor.dart';
import 'entry_fields.dart';

/// The + button: amount first, then what it was for. One sheet for both
/// expenses and income (switch at the top).
Future<void> showAddEntrySheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _AddEntrySheet(),
    );

class _AddEntrySheet extends ConsumerStatefulWidget {
  const _AddEntrySheet();

  @override
  ConsumerState<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends ConsumerState<_AddEntrySheet> {
  final _amount = TextEditingController();
  final _payee = TextEditingController();
  final _notes = TextEditingController();
  bool _income = false;
  String? _label;
  DateTime _date = DateTime.now();
  String? _error;
  bool _saving = false;
  bool _splitting = false;

  @override
  void initState() {
    super.initState();
    // The split view's total follows the amount as it's typed.
    _amount.addListener(() {
      if (_splitting) setState(() {});
    });
  }

  double get _total => double.tryParse(_amount.text.trim()) ?? 0;

  @override
  void dispose() {
    _amount.dispose();
    _payee.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<ExpenseCategory> get _options => _income
      ? ref.watch(incomeSourceProvider).valueOrNull ?? []
      : ref.watch(categoryProvider).valueOrNull ?? [];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          Space.xl, 0, Space.xl, Space.xl + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _kindSwitch(),
        const SizedBox(height: Space.l),
        AmountField(controller: _amount, autofocus: true),
        const SizedBox(height: Space.l),
        if (_splitting) ...[
          _whenAndWho(),
          const SizedBox(height: Space.l),
          _splitEditor(),
        ] else
          ..._pickOne(),
      ]),
    );
  }

  List<Widget> _pickOne() => [
        Text(_income ? 'Source' : 'Category', style: context.text.titleSmall),
        const SizedBox(height: Space.s),
        _chips(),
        if (!_income)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _startSplit,
              icon: const Icon(Icons.call_split_rounded),
              label: const Text('Split across categories'),
            ),
          ),
        const SizedBox(height: Space.l),
        _whenAndWho(),
        if (_error != null) ...[
          const SizedBox(height: Space.m),
          Text(_error!, style: context.text.bodyMedium?.copyWith(color: context.colors.error)),
        ],
        const SizedBox(height: Space.xl),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_income ? 'Add income' : 'Add expense'),
        ),
      ];

  /// Date, payee and (unless splitting, where each part has one) note.
  Widget _whenAndWho() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EntryDateRow(date: _date, onTap: _pickDate, accent: context.colors.primary),
        const SizedBox(height: Space.m),
        PayeeAndNoteFields(payee: _payee, note: _notes, income: _income, showNote: !_splitting),
      ]);

  void _startSplit() {
    if (_total <= 0) return setState(() => _error = 'Enter the amount first');
    setState(() {
      _splitting = true;
      _error = null;
    });
  }

  Widget _splitEditor() => SplitEditor(
        total: _total,
        initial: [if (_label != null) SplitPart(_label!, 0)],
        onCancel: () => setState(() => _splitting = false),
        onSave: (parts) async {
          final payment = Expense(
              amount: _total, category: parts.first.category, date: _date, payee: textOrNull(_payee));
          await ref.read(expenseProvider.notifier).saveSplit(payment, parts);
          if (!mounted) return;
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          messenger.showSnackBar(const SnackBar(content: Text('Split payment added')));
        },
      );

  Widget _kindSwitch() => SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('Expense'), icon: Icon(Icons.north_east_rounded)),
          ButtonSegment(value: true, label: Text('Income'), icon: Icon(Icons.south_west_rounded)),
        ],
        selected: {_income},
        onSelectionChanged: (s) => setState(() {
          _income = s.first;
          _label = null;
        }),
      );

  Widget _chips() => Wrap(spacing: Space.s, runSpacing: Space.s, children: [
        for (final option in _options)
          CategoryChip(
            emoji: option.emoji,
            label: option.name,
            color: option.color,
            selected: _label == option.name,
            onTap: () => setState(() => _label = option.name),
          ),
        CategoryChip(
          emoji: '+',
          label: 'New',
          color: context.colors.primary,
          selected: false,
          onTap: _newLabel,
        ),
      ]);

  Future<void> _pickDate() async {
    final picked = await pickEntryDate(context, _date);
    if (picked != null) setState(() => _date = picked);
  }

  void _newLabel() {
    final income = _income;
    showCategorySheet(
      context,
      title: income ? 'New income source' : 'New category',
      buttonLabel: 'Create',
      hint: income ? 'e.g. Bonus, Cashback' : 'e.g. Gym, Pets',
      usedColors: {..._options.map((c) => c.colorValue)},
      nameError: income
          ? ref.read(incomeSourceProvider.notifier).nameError
          : ref.read(categoryProvider.notifier).nameError,
      onSaved: (created) async {
        income
            ? await ref.read(incomeSourceProvider.notifier).addSource(created)
            : await ref.read(categoryProvider.notifier).addCategory(created);
        if (mounted) setState(() => _label = created.name);
      },
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) return setState(() => _error = 'Enter an amount');
    if (_label == null) return setState(() => _error = 'Pick a ${_income ? 'source' : 'category'}');
    setState(() => _saving = true); // a second tap can't save twice
    final payee = textOrNull(_payee);
    final notes = textOrNull(_notes);
    if (_income) {
      await ref.read(incomeProvider.notifier).addIncome(
          Income(amount: amount, source: _label!, date: _date, payee: payee, notes: notes));
    } else {
      await ref.read(expenseProvider.notifier).addExpense(
          Expense(amount: amount, category: _label!, date: _date, payee: payee, notes: notes));
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(_income ? 'Income added' : 'Expense added')));
  }
}
