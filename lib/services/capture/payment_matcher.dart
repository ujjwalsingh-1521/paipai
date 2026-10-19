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

  /// Some bank apps alert well after the SMS and carry no reference (the
  /// Kotak 811 app: 14 to 40 min). When the other alert has one and both name
  /// the same account, they're allowed this far apart.
  static const lateAlertWindow = Duration(minutes: 90);

  /// Another app naming the same payee, without account numbers to compare.
  static const samePayeeWindow = Duration(hours: 3);

  /// The closest in time, so a late alert joins its own payment rather
  /// than an earlier one of the same amount.
  static PendingTransaction? findSamePayment(ParsedPayment payment, List<PendingTransaction> recent) {
    Duration gap(PendingTransaction record) => payment.source.postedAt.difference(record.detectedAt).abs();
    final matches = recent.where((record) => isSamePayment(payment, record)).toList()
      ..sort((a, b) => gap(a).compareTo(gap(b)));
    return matches.firstOrNull;
  }

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
    if (involvesEmail) return emailWindow;
    // Only across apps: one app reporting the same shop twice, far apart, is
    // more likely two payments (two ₹20 chais).
    // Each app reports a payment once: a second alert from an app this
    // record already has is another payment (a UPI Lite one only the bank
    // app reports, half an hour after an SMS of the same amount).
    if (_hasAlertFrom(record, payment.source.app)) return fuzzyWindow;
    if (_lateAlert(payment, record)) return lateAlertWindow;
    return _similarPayees(payment.payee, record.merchant) ? samePayeeWindow : fuzzyWindow;
  }

  static bool _hasAlertFrom(PendingTransaction record, String app) {
    if (record.sourceApp == app) return true;
    final heading = '${AppKinds.label(app)} · ';
    return CaptureMessages.split(record.rawMessage).skip(1).any((m) => m.heading?.startsWith(heading) ?? false);
  }

  /// One alert has a reference and the other doesn't, on the same account,
  /// and they don't name different payees.
  static bool _lateAlert(ParsedPayment payment, PendingTransaction record) =>
      (payment.reference == null) != (record.upiRef == null) &&
      payment.accountTail != null &&
      record.accountTail != null &&
      !_differentPayees(payment.payee, record.merchant);

  /// Both are readable names and not alike ("Swiggy" and "Ravi Kumar").
  static bool _differentPayees(String? a, String? b) =>
      _nameKey(a) != null && _nameKey(b) != null && !_similarPayees(a, b);

  /// "KARAN  MEHTA" and "Karan Mehta"; "Ganesh Vegitable" and "Ganesh
  /// Vegitable shop" (one app adds a word). UPI ids aren't names.
  static bool _similarPayees(String? a, String? b) {
    final keyA = _nameKey(a);
    final keyB = _nameKey(b);
    if (keyA == null || keyB == null) return false;
    final (shorter, longer) = keyA.length <= keyB.length ? (keyA, keyB) : (keyB, keyA);
    return shorter == longer || (shorter.length >= 6 && longer.startsWith(shorter));
  }

  static String? _nameKey(String? payee) {
    if (payee == null || payee.contains('@')) return null;
    final key = payee.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return key.isEmpty ? null : key;
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
    // The fuller name: "Ganesh Vegitable shop" over "Ganesh Vegitable".
    final currentKey = _nameKey(current);
    final candidateKey = _nameKey(candidate);
    if (currentKey != null && candidateKey != null &&
        candidateKey.length > currentKey.length && candidateKey.startsWith(currentKey)) {
      return candidate;
    }
    return current;
  }
}
