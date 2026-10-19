import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/pending_transaction.dart';
import '../providers/pending_transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/payment_review_sheet.dart';
import '../widgets/ui.dart';

final _dateFormat = DateFormat('dd MMM · hh:mm a');

class PendingTransactionsScreen extends ConsumerWidget {
  const PendingTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingTransactionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Payments to review')),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => items.isEmpty ? _empty() : _list(ref, items),
      ),
    );
  }

  Widget _empty() => const Center(
        child: EmptyNote(
          icon: Icons.task_alt_rounded,
          title: 'All caught up',
          message: 'No payments are waiting for a category.',
        ),
      );

  Widget _list(WidgetRef ref, List<PendingTransaction> items) => ListView(
        padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, Space.xxl),
        children: [
          Builder(
            builder: (context) => FilledButton.icon(
              onPressed: () => reviewPendingPayments(context, ref),
              icon: const Icon(Icons.label_important_rounded),
              label: const Text('Label one by one'),
            ),
          ),
          const SizedBox(height: Space.s),
          Builder(
            builder: (context) => Text("Tap one to label it, or swipe it away if it isn't a payment.",
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ),
          const SizedBox(height: Space.m),
          GroupCard(children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(indent: Space.l, endIndent: Space.l),
              _PendingRow(
                tx: items[i],
                onDismissed: () =>
                    ref.read(pendingTransactionProvider.notifier).dismiss(items[i].id!),
              ),
            ],
          ]),
        ],
      );
}

/// One captured payment: tap to review, swipe left to dismiss.
class _PendingRow extends StatelessWidget {
  final PendingTransaction tx;
  final VoidCallback onDismissed;

  const _PendingRow({required this.tx, required this.onDismissed});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('pending_${tx.id}'),
      direction: DismissDirection.endToStart,
      background: _dismissBackground(context),
      onDismissed: (_) => onDismissed(),
      child: ListTile(
        onTap: () => showPaymentReviewSheet(context, tx),
        leading: _DirectionIcon(isDebit: tx.isDebit),
        title: Text(tx.merchant ?? tx.sender, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(_dateFormat.format(tx.detectedAt)),
        trailing: Text(
          '${tx.isDebit ? '' : '+'}${formatMoney(tx.amount)}',
          style: context.text.titleSmall?.copyWith(
              color: tx.isDebit ? context.colors.onSurface : context.money.income),
        ),
      ),
    );
  }

  Widget _dismissBackground(BuildContext context) => Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.xl),
        color: context.colors.errorContainer,
        child: Icon(Icons.delete_outline_rounded, color: context.colors.onErrorContainer),
      );
}

/// Arrow out for money paid, arrow in for money received.
class _DirectionIcon extends StatelessWidget {
  final bool isDebit;
  const _DirectionIcon({required this.isDebit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isDebit ? Icons.north_east_rounded : Icons.south_west_rounded,
        size: 20,
        color: isDebit ? context.colors.onSurfaceVariant : context.money.income,
      ),
    );
  }
}
