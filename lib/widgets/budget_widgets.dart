import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/budget_provider.dart';
import '../theme/app_theme.dart';
import '../utils/budgets.dart';
import '../utils/money.dart';
import 'entry_fields.dart';

/// Colour of a budget's bar and status: primary when on track, tertiary
/// when spending faster than the month allows, error once it's over.
Color budgetColor(BuildContext context, BudgetPace pace) => switch (pace) {
      BudgetPace.onTrack => context.colors.primary,
      BudgetPace.ahead => context.colors.tertiary,
      BudgetPace.over => context.colors.error,
    };

/// How much of a budget is used, with a tick where an even pace would be
/// by today (left out once the month is over).
class BudgetBar extends StatelessWidget {
  final BudgetStatus status;
  final double height;

  const BudgetBar({super.key, required this.status, this.height = Space.s});

  @override
  Widget build(BuildContext context) {
    final color = budgetColor(context, status.pace);
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return SizedBox(
        height: height + Space.xs,
        child: Stack(alignment: Alignment.centerLeft, children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(height),
            ),
          ),
          Container(
            width: width * status.used.clamp(0.0, 1.0),
            height: height,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height)),
          ),
          if (!status.isFinished)
            Positioned(
              left: (width * status.evenPaceShare - 1).clamp(0.0, width - 2),
              child: Container(width: 2, height: height + Space.xs, color: context.colors.onSurface),
            ),
        ]),
      );
    });
  }
}

/// The monthly budget at a glance: what's left, the bar, the status line
/// and what's still waiting for a label. [onTap] opens more detail.
class BudgetCard extends StatelessWidget {
  final BudgetStatus status;
  final String title;

  /// Captured payments not counted yet because they have no category.
  final double waiting;
  final VoidCallback? onTap;

  const BudgetCard({super.key, required this.status, required this.title, this.waiting = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    final over = status.pace == BudgetPace.over;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: context.text.titleMedium)),
              if (onTap != null) Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant),
            ]),
            const SizedBox(height: Space.xs),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Expanded(
                child: Text(over ? '${formatMoney(-status.left)} over' : '${formatMoney(status.left)} left',
                    style: context.text.headlineSmall?.copyWith(color: over ? context.colors.error : null)),
              ),
              Text('of ${formatMoney(status.limit)}', style: muted),
            ]),
            const SizedBox(height: Space.s),
            BudgetBar(status: status),
            const SizedBox(height: Space.s),
            Text(BudgetText.statusLine(status),
                style: muted?.copyWith(color: status.pace == BudgetPace.onTrack ? null : budgetColor(context, status.pace))),
            if (waiting > 0) Text('+ ${formatMoney(waiting)} waiting to be labelled', style: muted),
          ]),
        ),
      ),
    );
  }
}

/// "Monthly budget" / "Food budget": the amount, with Remove when one is set.
Future<void> showBudgetAmountSheet(BuildContext context,
        {required String category, required String title, double? current}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BudgetAmountSheet(category: category, title: title, current: current),
    );

class _BudgetAmountSheet extends ConsumerStatefulWidget {
  final String category;
  final String title;
  final double? current;

  const _BudgetAmountSheet({required this.category, required this.title, this.current});

  @override
  ConsumerState<_BudgetAmountSheet> createState() => _BudgetAmountSheetState();
}

class _BudgetAmountSheetState extends ConsumerState<_BudgetAmountSheet> {
  late final _amount = TextEditingController(text: _initialText());
  bool _saving = false;

  String _initialText() {
    final current = widget.current;
    if (current == null) return '';
    return current == current.roundToDouble() ? current.toStringAsFixed(0) : '$current';
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save(double? amount) async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref.read(budgetProvider.notifier).setBudget(widget.category, amount);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.title, style: context.text.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: Space.s),
        Text('How much can you spend each month? It starts again on the 1st.',
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            textAlign: TextAlign.center),
        const SizedBox(height: Space.l),
        AmountField(controller: _amount, autofocus: widget.current == null),
        const SizedBox(height: Space.xl),
        Row(children: [
          if (widget.current != null) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => _save(null),
                child: const Text('Remove'),
              ),
            ),
            const SizedBox(width: Space.m),
          ],
          Expanded(
            child: ListenableBuilder(
              listenable: _amount,
              builder: (context, _) {
                final value = double.tryParse(_amount.text.trim());
                final valid = value != null && value > 0;
                return FilledButton(onPressed: _saving || !valid ? null : () => _save(value), child: const Text('Save'));
              },
            ),
          ),
        ]),
      ]),
    );
  }
}
