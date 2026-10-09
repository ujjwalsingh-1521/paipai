import 'app_kinds.dart';

enum PaymentDirection { debit, credit }

/// One notification (or one message inside a conversation notification)
/// as delivered by the native listener.
class NotificationInput {
  /// Android package that posted it, e.g. 'com.google.android.apps.messaging'.
  final String app;

  /// Notification title; for SMS apps this is the sender ('AX-HDFCBK').
  final String title;
  final String text;
  final DateTime postedAt;

  /// Stable per message: the same id + text means Android re-posted it.
  final String messageId;

  const NotificationInput({
    required this.app,
    required this.title,
    required this.text,
    required this.postedAt,
    this.messageId = '',
  });

  factory NotificationInput.fromMap(Map<Object?, Object?> map) =>
      NotificationInput(
        app: map['app'] as String? ?? '',
        title: map['title'] as String? ?? '',
        text: map['text'] as String? ?? '',
        postedAt: DateTime.fromMillisecondsSinceEpoch(
            map['postedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
        messageId: map['messageId'] as String? ?? '',
      );
}

/// A money movement recognised in a notification.
class ParsedPayment {
  final double amount;
  final PaymentDirection direction;
  final String? payee;
  final String? reference;
  final String? accountTail;
  final NotificationInput source;

  const ParsedPayment({
    required this.amount,
    required this.direction,
    required this.source,
    this.payee,
    this.reference,
    this.accountTail,
  });

  bool get isDebit => direction == PaymentDirection.debit;

  @override
  String toString() => 'ParsedPayment(${direction.name} $amount, '
      'payee: $payee, ref: $reference, tail: $accountTail)';
}

/// One payment can be seen in several alerts (SMS, UPI app, email). The
/// first alert's text is stored as-is; each later one is appended under a
/// "seen in" line, so the payment's details show every message.
abstract final class CaptureMessages {
  static const _marker = '\n\n── ';

  static String append(String stored, NotificationInput next) {
    final time = '${next.postedAt.hour.toString().padLeft(2, '0')}:'
        '${next.postedAt.minute.toString().padLeft(2, '0')}';
    return '$stored$_marker${AppKinds.label(next.app)} · ${next.title} · $time ──\n${next.text}';
  }

  /// [stored] split back into (heading, text) pairs; the first heading is null.
  static List<({String? heading, String text})> split(String stored) {
    final parts = stored.split(_marker);
    return [
      (heading: null, text: parts.first),
      for (final part in parts.skip(1))
        (
          heading: part.substring(0, part.indexOf('\n')).replaceAll('──', '').trim(),
          text: part.substring(part.indexOf('\n') + 1),
        ),
    ];
  }

  /// UPI ids in the messages ("sharma@okaxis"), not email addresses
  /// (an email's domain continues with ".com"; a full stop ending a sentence is fine).
  static List<String> upiIds(String stored) => {
        for (final m in RegExp(r'\b[a-zA-Z0-9._-]{2,}@[a-zA-Z]{2,}\b(?!\.[a-zA-Z])').allMatches(stored)) m[0]!,
      }.toList();
}
