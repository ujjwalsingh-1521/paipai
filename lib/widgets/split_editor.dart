import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../models/split_part.dart';
import '../providers/category_provider.dart';
import '../theme/app_theme.dart';
import '../utils/analytics.dart';
import '../utils/money.dart';
import 'category_chip.dart';
import 'category_icon.dart';

/// Split view: tap the categories a payment was spread across, type the
/// smaller parts; the first category picked takes whatever is left.
class SplitEditor extends ConsumerStatefulWidget {
  final double total;
  final List<SplitPart> initial;
  final Future<void> Function(List<SplitPart> parts) onSave;
  final VoidCallback onCancel;
  final String cancelLabel;

  const SplitEditor({
    super.key,
    required this.total,
    required this.onSave,
    required this.onCancel,
    this.initial = const [],
    this.cancelLabel = 'Cancel split',
  });

  @override
  ConsumerState<SplitEditor> createState() => _SplitEditorState();
}

class _PartInput {
  final String category;
  final TextEditingController amount;
  final TextEditingController note;
  bool showNote;

  _PartInput(this.category, {double amount = 0, String? note})
      : amount = TextEditingController(text: amount > 0 ? _plain(amount) : ''),
        note = TextEditingController(text: note ?? ''),
        showNote = note != null && note.isNotEmpty;

  static String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  SplitPart toPart() => SplitPart(category, double.tryParse(amount.text.trim()) ?? 0,
      note: note.text.trim().isEmpty ? null : note.text.trim());

  void dispose() {
    amount.dispose();
    note.dispose();
  }
}

class _SplitEditorState extends ConsumerState<SplitEditor> {
  late final List<_PartInput> _parts = [
    for (final p in widget.initial) _PartInput(p.category, amount: p.amount, note: p.note),
  ];
  bool _saving = false;

  @override
  void dispose() {
    for (final p in _parts) {
      p.dispose();
    }
    super.dispose();
  }

  List<SplitPart> get _computed => withRemainder(widget.total, [for (final p in _parts) p.toPart()]);

  void _toggle(String category) {
    setState(() {
      final index = _parts.indexWhere((p) => p.category == category);
      if (index < 0) {
        _parts.add(_PartInput(category));
      } else {
        _parts.removeAt(index).dispose();
      }
    });
  }

  Future<void> _save() async {
    final parts = _computed;
    if (_saving || splitError(widget.total, parts) != null) return;
    setState(() => _saving = true); // a second tap can't save twice
    try {
      await widget.onSave(parts);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parts = _computed;
    final error = splitError(widget.total, parts);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Split ${formatMoney(widget.total)}: tap the categories', style: context.text.titleSmall),
      Text('The first one you pick takes whatever is left.',
          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
      const SizedBox(height: Space.s),
      _chips(),
      if (_parts.isNotEmpty) ...[
        const SizedBox(height: Space.m),
        _partsBlock(parts),
      ],
      const SizedBox(height: Space.m),
      _status(error),
      const SizedBox(height: Space.m),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: widget.onCancel, child: Text(widget.cancelLabel))),
        const SizedBox(width: Space.m),
        Expanded(
          child: FilledButton(
            onPressed: error == null && !_saving ? _save : null,
            child: const Text('Save split'),
          ),
        ),
      ]),
    ]);
  }

  Widget _chips() {
    final categories = ref.watch(categoryProvider).valueOrNull ?? [];
    final picked = {for (final p in _parts) p.category};
    return Wrap(spacing: Space.s, runSpacing: Space.s, children: [
      for (final c in categories)
        CategoryChip(
          emoji: c.emoji,
          label: c.name,
          color: c.color,
          selected: picked.contains(c.name),
          onTap: () => _toggle(c.name),
          compact: true,
        ),
    ]);
  }

  Widget _partsBlock(List<SplitPart> computed) {
    final categories = ref.watch(categoryProvider).valueOrNull ?? [];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.xs),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Corners.medium),
      ),
      child: Column(children: [
        for (var i = 0; i < _parts.length; i++)
          _PartRow(
            input: _parts[i],
            isRest: i == 0,
            restAmount: computed.first.amount,
            category: findCategory(categories, _parts[i].category),
            onChanged: () => setState(() {}),
            onRemove: () => _toggle(_parts[i].category),
          ),
      ]),
    );
  }

  Widget _status(String? error) {
    if (_parts.isEmpty) return const SizedBox.shrink();
    final ok = error == null;
    return Row(children: [
      Icon(ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          size: 18, color: ok ? context.money.income : context.colors.onSurfaceVariant),
      const SizedBox(width: Space.s),
      Expanded(
        child: Text(ok ? 'Adds up to ${formatMoney(widget.total)}' : error,
            style: context.text.bodyMedium?.copyWith(
                color: ok ? context.money.income : context.colors.onSurfaceVariant)),
      ),
    ]);
  }
}

/// "[icon] Snacks  [note] [₹ 400] ✕"; the first part shows "the rest".
class _PartRow extends StatelessWidget {
  final _PartInput input;
  final bool isRest;
  final double restAmount;
  final ExpenseCategory category;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _PartRow({
    required this.input,
    required this.isRest,
    required this.restAmount,
    required this.category,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Column(children: [
        Row(children: [
          CategoryIcon(symbol: category.emoji, color: category.color, size: 32),
          const SizedBox(width: Space.s),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(category.name, style: context.text.bodyLarge, overflow: TextOverflow.ellipsis),
              if (isRest) Text('the rest', style: muted),
            ]),
          ),
          IconButton(
            tooltip: 'Add a note',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.edit_note_rounded,
                color: input.showNote ? context.colors.primary : context.colors.onSurfaceVariant),
            onPressed: () {
              input.showNote = !input.showNote;
              onChanged();
            },
          ),
          SizedBox(width: 96, child: isRest ? _restAmount(context) : _amountField(context)),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: onRemove,
          ),
        ]),
        if (input.showNote)
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: Space.xs),
            child: TextField(
              controller: input.note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(isDense: true, hintText: 'Note, e.g. chips'),
            ),
          ),
      ]),
    );
  }

  Widget _restAmount(BuildContext context) => Text(
        formatMoney(restAmount),
        textAlign: TextAlign.right,
        style: context.text.titleSmall?.copyWith(
            color: restAmount <= 0 ? context.colors.error : context.colors.onSurface),
      );

  Widget _amountField(BuildContext context) => TextField(
        controller: input.amount,
        textAlign: TextAlign.right,
        style: context.text.titleSmall,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
        decoration: const InputDecoration(isDense: true, prefixText: '₹ ', hintText: '0'),
        onChanged: (_) => onChanged(),
      );
}
