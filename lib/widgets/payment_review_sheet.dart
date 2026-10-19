import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/pending_transaction.dart';
import '../models/split_part.dart';
import '../providers/pending_transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/income_source_provider.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import 'category_chip.dart';
import 'entry_fields.dart';
import 'payment_details.dart';
import 'split_editor.dart';

final _dateFormat = DateFormat('dd MMM yyyy · hh:mm a');

enum ReviewResult { saved, notAPayment, later }

const recentReview = Duration(days: 3);

bool _reviewing = false;

/// Shows "What was this?" for each payment not yet labelled, one after
/// another, until the user picks Later. [startWith] goes first (the payment
/// a notification was tapped for). [recentOnly] skips payments older than
/// [recentReview] (say, imported from old SMS) when asking unprompted.
Future<void> reviewPendingPayments(
  BuildContext context,
  WidgetRef ref, {
  int? startWith,
  bool recentOnly = false,
}) async {
  if (_reviewing) return;
  _reviewing = true;
  try {
    var nextId = startWith;
    while (context.mounted) {
      final pending = await ref
          .read(pendingTransactionProvider.notifier)
          .latest();
      final cutoff = DateTime.now().subtract(recentReview);
      final tx =
          pending.where((t) => t.id == nextId).firstOrNull ??
          pending.where((t) => !recentOnly || t.detectedAt.isAfter(cutoff)).lastOrNull;
      if (tx == null || !context.mounted) return;
      final result = await showPaymentReviewSheet(context, tx);
      if (result == ReviewResult.later) return;
      nextId = null;
    }
  } finally {
    _reviewing = false;
  }
}

/// Closing the sheet without choosing counts as Later.
Future<ReviewResult> showPaymentReviewSheet(
  BuildContext context,
  PendingTransaction tx,
) async {
  final result = await showModalBottomSheet<ReviewResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Scrolls if many categories don't fit on a small screen.
    builder: (sheetContext) => SingleChildScrollView(
      // Lifts the sheet above the keyboard while the note is typed.
      padding: EdgeInsets.fromLTRB(Space.xl, 0, Space.xl,
          Space.l + MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: _TransactionSheet(transaction: tx),
    ),
  );
  return result ?? ReviewResult.later;
}

class _TransactionSheet extends ConsumerStatefulWidget {
  final PendingTransaction transaction;
  const _TransactionSheet({required this.transaction});

  @override
  ConsumerState<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<_TransactionSheet> {
  String? _selected;
  bool _splitting = false;
  String? _usual;
  // Category names, best guess first; null until loaded.
  List<String>? _order;
  bool _saving = false;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final suggestions = await ref
        .read(pendingTransactionProvider.notifier)
        .suggestionsFor(widget.transaction);
    if (!mounted) return;
    setState(() {
      _order = suggestions.ordered;
      _usual = suggestions.usual;
      // What this shop usually is comes pre-selected: one tap on Save.
      _selected ??= suggestions.usual;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(pendingTransactionProvider.notifier)
          .categorize(widget.transaction.id!, _selected!, note: _note.text);
      if (mounted) Navigator.pop(context, ReviewResult.saved);
    } catch (error) {
      // Leave Save usable so the user can try again.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text('Couldn\'t save: $error')));
    }
  }

  /// [items] in suggestion order (unknown names keep their place at the end).
  List<T> _sorted<T>(List<T> items, String Function(T) name) {
    final order = _order;
    if (order == null) return items;
    int rank(T item) {
      final index = order.indexOf(name(item));
      return index < 0 ? order.length : index;
    }

    return [...items]..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  Future<void> _notAPayment() async {
    await ref
        .read(pendingTransactionProvider.notifier)
        .dismiss(widget.transaction.id!);
    if (mounted) Navigator.pop(context, ReviewResult.notAPayment);
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AmountHeader(transaction: tx),
        const SizedBox(height: Space.l),
        _Details(transaction: tx),
        if (tx.maybeMultiple) _SeparateBanner(transaction: tx),
        const SizedBox(height: Space.xl),
        if (_splitting) _splitEditor() else ..._pickOne(colors),
      ],
    );
  }

  /// The usual view: pick one category, Save.
  List<Widget> _pickOne(ColorScheme colors) {
    final tx = widget.transaction;
    return [
      Text(
        _usual != null
            ? 'Usually $_usual here'
            : (tx.isDebit ? 'Pick a category' : 'Pick a source'),
        style: context.text.titleSmall,
      ),
      const SizedBox(height: Space.m),
      _chips(),
      if (tx.isDebit)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _splitting = true),
            icon: const Icon(Icons.call_split_rounded),
            label: const Text('Split across categories'),
          ),
        ),
      const SizedBox(height: Space.s),
      TextField(
        controller: _note,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Note',
          prefixIcon: Icon(Icons.notes_rounded),
        ),
      ),
      const SizedBox(height: Space.l),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _notAPayment,
              child: const Text('Not a payment'),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: FilledButton(
              onPressed: _selected == null || _saving ? null : _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      const SizedBox(height: Space.xs),
      Center(
        child: TextButton(
          onPressed: () => Navigator.pop(context, ReviewResult.later),
          style: TextButton.styleFrom(foregroundColor: colors.onSurfaceVariant),
          child: const Text('Later'),
        ),
      ),
    ];
  }

  /// Same card, split view; a picked category becomes the first part.
  Widget _splitEditor() => SplitEditor(
    total: widget.transaction.amount,
    // The note typed so far goes with the first part.
    initial: [if (_selected != null) SplitPart(_selected!, 0, note: textOrNull(_note))],
    onCancel: () => setState(() => _splitting = false),
    onSave: (parts) async {
      await ref
          .read(pendingTransactionProvider.notifier)
          .categorizeSplit(widget.transaction.id!, parts);
      if (mounted) Navigator.pop(context, ReviewResult.saved);
    },
  );

  Widget _chips() {
    final tx = widget.transaction;
    final itemsAsync = tx.isDebit
        ? ref.watch(categoryProvider)
        : ref.watch(incomeSourceProvider);
    return itemsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(Space.l),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text(
        'Error: $e',
        style: context.text.bodyMedium?.copyWith(color: context.colors.error),
      ),
      data: (items) => Wrap(
        spacing: Space.s,
        runSpacing: Space.s,
        children: [
          for (final item in _sorted(items, (c) => c.name))
            CategoryChip(
              emoji: item.emoji,
              label: item.name,
              color: item.color,
              selected: _selected == item.name,
              onTap: () => setState(() => _selected = item.name),
              compact: true,
            ),
        ],
      ),
    );
  }
}

/// "Paid to Blinkit" above the amount, large.
class _AmountHeader extends StatelessWidget {
  final PendingTransaction transaction;
  const _AmountHeader({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final colors = context.colors;
    final merchant = tx.merchant;
    final label = tx.isDebit
        ? (merchant != null ? 'Paid to $merchant' : 'Payment')
        : (merchant != null ? 'Received from $merchant' : 'Money received');
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.titleMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          formatMoney(tx.amount),
          textAlign: TextAlign.center,
          style: context.text.displaySmall?.copyWith(
            color: tx.isDebit ? colors.onSurface : context.money.income,
          ),
        ),
      ],
    );
  }
}

/// When, account and UPI reference as quiet rows on a tonal block.
class _Details extends StatelessWidget {
  final PendingTransaction transaction;
  const _Details({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.l,
        vertical: Space.m,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Corners.medium),
      ),
      child: Column(
        // Stretch, so "Show original message" lines up with the rows.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailRow(
            icon: Icons.schedule_rounded,
            label: 'When',
            value: _dateFormat.format(tx.detectedAt),
          ),
          if (tx.accountTail != null)
            _DetailRow(
              icon: Icons.account_balance_rounded,
              label: 'Account',
              value: 'XX${tx.accountTail}',
            ),
          if (tx.upiRef != null)
            _DetailRow(
              icon: Icons.tag_rounded,
              label: 'UPI Ref',
              value: tx.upiRef!,
            ),
          _DetailRow(
            icon: Icons.notifications_none_rounded,
            label: 'Seen in',
            value: seenIn(tx),
          ),
          OriginalMessages(capture: tx),
        ],
      ),
    );
  }
}

/// Shown when two alerts were merged on amount and time alone (same app, no
/// shared reference), which might really have been two payments.
class _SeparateBanner extends ConsumerWidget {
  final PendingTransaction transaction;
  const _SeparateBanner({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: Space.m),
      padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.xs, Space.s),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(Corners.medium),
      ),
      child: Row(
        children: [
          Icon(
            Icons.copy_all_rounded,
            size: 20,
            color: colors.onTertiaryContainer,
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Text(
              'Seen ${transaction.seenCount} times from the same app. '
              'Were these separate payments?',
              style: context.text.bodySmall?.copyWith(
                color: colors.onTertiaryContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(pendingTransactionProvider.notifier)
                  .splitOff(transaction.id!);
              if (context.mounted) Navigator.pop(context, ReviewResult.saved);
            },
            style: TextButton.styleFrom(
              foregroundColor: colors.onTertiaryContainer,
            ),
            child: const Text('Separate'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final quiet = context.text.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: Space.m),
          Text(label, style: quiet),
          const SizedBox(width: Space.l),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.text.bodyMedium?.copyWith(color: colors.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
