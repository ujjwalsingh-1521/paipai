import '../../models/pending_transaction.dart';
import 'app_kinds.dart';
import 'parsed_payment.dart';

/// Decides whether a newly parsed alert is a payment already recorded from
/// another notification (bank SMS + UPI app + email for one payment), and
/// merges the details when it is.
class PaymentMatcher {
  /// How far back to look; a matching reference number merges even if the
  /// second alert (often an email) arrives hours later.
  static const lookback = Duration(hours: 48);

  /// Without a shared reference, alerts must be this close in time.
  static const fuzzyWindow = Duration(minutes: 10);

  /// Emails are often delayed, so allow more time when one side is email.
  static const emailWindow = Duration(hours: 3);

  static PendingTransaction? findSamePayment(
          ParsedPayment payment, List<PendingTransaction> recent) =>
      recent.where((record) => isSamePayment(payment, record)).firstOrNull;

  static bool isSamePayment(ParsedPayment payment, PendingTransaction record) {
    if (payment.isDebit != record.isDebit) return false;
    if ((payment.amount - record.amount).abs() >= 0.01) return false;
    final ref = payment.reference;
    if (ref != null && record.upiRef != null) return ref == record.upiRef;
    if (_tailsConflict(payment.accountTail, record.accountTail)) return false;
    final gap = payment.source.postedAt.difference(record.detectedAt).abs();
    return gap <= _windowFor(payment, record);
  }

  static Duration _windowFor(ParsedPayment payment, PendingTransaction record) {
    final involvesEmail = AppKinds.of(payment.source.app) == AppKind.email ||
        AppKinds.of(record.sourceApp ?? '') == AppKind.email;
    return involvesEmail ? emailWindow : fuzzyWindow;
  }

  /// "XXXXX123" and "*0123" may be the same account; only clearly different
  /// tails prove two different accounts.
  static bool _tailsConflict(String? a, String? b) =>
      a != null && b != null && !a.endsWith(b) && !b.endsWith(a);

  /// Folds a newly seen alert into the record it duplicates.
  static PendingTransaction merge(
      PendingTransaction existing, ParsedPayment payment) {
    final refMatched =
        payment.reference != null && payment.reference == existing.upiRef;
    final sameApp = payment.source.app == existing.sourceApp;
    return existing.copyWith(
      merchant: betterPayee(existing.merchant, payment.payee),
      upiRef: existing.upiRef ?? payment.reference,
      accountTail: existing.accountTail ?? payment.accountTail,
      seenCount: existing.seenCount + 1,
      // Every alert's text is kept, so the payment's details show all of them.
      rawMessage: CaptureMessages.append(existing.rawMessage, payment.source),
      // Two alerts from the same app with no shared reference could be two
      // genuine payments of the same amount (two ₹20 chais).
      maybeMultiple: existing.maybeMultiple || (!refMatched && sameApp),
    );
  }

  /// Prefers a readable name ("Sharma Store") over a UPI id ("sharma@okaxis").
  static String? betterPayee(String? current, String? candidate) {
    if (candidate == null) return current;
    if (current == null) return candidate;
    if (current.contains('@') && !candidate.contains('@')) return candidate;
    return current;
  }
}
