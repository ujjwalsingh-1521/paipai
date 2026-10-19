import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/pending_transaction.dart';
import '../services/capture/app_kinds.dart';
import '../services/capture/parsed_payment.dart';
import '../theme/app_theme.dart';

/// For an entry saved from a captured payment: transaction id, UPI id,
/// account, where it was seen, and every original message. Shows nothing
/// for entries added by hand.
class PaymentDetails extends StatefulWidget {
  final int? expenseId;
  final int? incomeId;

  const PaymentDetails({super.key, this.expenseId, this.incomeId});

  @override
  State<PaymentDetails> createState() => _PaymentDetailsState();
}

class _PaymentDetailsState extends State<PaymentDetails> {
  late final Future<PendingTransaction?> _capture =
      DatabaseHelper().getCaptureFor(expenseId: widget.expenseId, incomeId: widget.incomeId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _capture,
      builder: (context, snapshot) {
        final capture = snapshot.data;
        if (capture == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: Space.l),
          child: _details(capture),
        );
      },
    );
  }

  Widget _details(PendingTransaction capture) {
    final upiIds = CaptureMessages.upiIds(capture.rawMessage);
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.s, Space.s),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Corners.medium),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Payment details', style: context.text.titleSmall),
        const SizedBox(height: Space.xs),
        if (capture.upiRef != null) _Row('Transaction ID', capture.upiRef!, copyable: true),
        for (final id in upiIds) _Row('UPI ID', id, copyable: true),
        if (capture.accountTail != null) _Row('Account', 'XX${capture.accountTail}'),
        _Row('Seen in', seenIn(capture)),
        _Row('Captured', DateFormat('d MMM yyyy · h:mm a').format(capture.detectedAt)),
        OriginalMessages(capture: capture),
      ]),
    );
  }
}

/// "Messages (SMS) + 2 more": where a captured payment was seen.
String seenIn(PendingTransaction capture) {
  final more = capture.seenCount - 1;
  return AppKinds.label(capture.sourceApp) + (more > 0 ? ' + $more more' : '');
}

/// "Show original messages": every alert a captured payment was built from,
/// with its app, sender and time. Collapsed until tapped.
class OriginalMessages extends StatefulWidget {
  final PendingTransaction capture;

  const OriginalMessages({super.key, required this.capture});

  @override
  State<OriginalMessages> createState() => _OriginalMessagesState();
}

class _OriginalMessagesState extends State<OriginalMessages> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final plural = widget.capture.seenCount > 1 ? 's' : '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _open = !_open),
          icon: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
          label: Text(_open ? 'Hide original message$plural' : 'Show original message$plural'),
        ),
      ),
      if (_open) ..._messages(),
    ]);
  }

  List<Widget> _messages() {
    final capture = widget.capture;
    final muted = context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant);
    return [
      for (final message in CaptureMessages.split(capture.rawMessage))
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, Space.s, Space.m),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message.heading ??
                '${AppKinds.label(capture.sourceApp)} · ${capture.sender} · ${DateFormat('HH:mm').format(capture.detectedAt)}',
                style: muted),
            const SizedBox(height: 2),
            SelectableText(message.text, style: context.text.bodySmall),
          ]),
        ),
    ];
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;

  const _Row(this.label, this.value, {this.copyable = false});

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    return SizedBox(
      height: 40,
      child: Row(children: [
        SizedBox(width: 112, child: Text(label, style: muted)),
        Expanded(
          child: Text(value, style: context.text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (copyable)
          IconButton(
            tooltip: 'Copy $label',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () => _copy(context),
          ),
      ]),
    );
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: value));
    messenger.showSnackBar(SnackBar(content: Text('$label copied')));
  }
}
