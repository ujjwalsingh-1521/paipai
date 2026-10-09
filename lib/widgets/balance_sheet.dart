import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/balance_provider.dart';
import '../theme/app_theme.dart';
import 'entry_fields.dart';

/// "What's your current bank balance?" — asked once on first open
/// ([firstTime], with Skip) and again whenever the balance card is tapped.
Future<void> showBalanceSheet(BuildContext context, {bool firstTime = false}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: !firstTime,
      builder: (_) => _BalanceSheet(firstTime: firstTime),
    );

class _BalanceSheet extends ConsumerStatefulWidget {
  final bool firstTime;
  const _BalanceSheet({required this.firstTime});

  @override
  ConsumerState<_BalanceSheet> createState() => _BalanceSheetState();
}

class _BalanceSheetState extends ConsumerState<_BalanceSheet> {
  final _amount = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_amount.text.trim());
    if (value == null || _saving) return;
    setState(() => _saving = true);
    await ref.read(balanceStartProvider.notifier).setBalance(value);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _skip() async {
    await ref.read(balanceStartProvider.notifier).skipPrompt();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Scrollable so Save stays reachable with the keyboard open on small phones.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          Space.xl, 0, Space.xl, Space.xl + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("What's your current bank balance?",
              style: context.text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: Space.s),
          Text(
            'Add up the money in your bank accounts right now. From here on, '
            'PaiPai keeps it up to date with every payment and income it records.',
            style: context.text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.l),
          AmountField(controller: _amount),
          const SizedBox(height: Space.xl),
          _buttons(),
        ],
      ),
    );
  }

  Widget _buttons() => Row(children: [
        if (widget.firstTime) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : _skip,
              child: const Text('Skip'),
            ),
          ),
          const SizedBox(width: Space.m),
        ],
        Expanded(
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ),
      ]);
}
