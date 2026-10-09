import '../../models/pending_transaction.dart';
import '../../utils/money.dart';
import 'capture_service.dart';

/// How capture results reach the user. The native implementation posts
/// Android notifications; tests can substitute a fake.
abstract class CaptureAlerts {
  /// "₹250 paid · Sharma Store" with the top suggestions as buttons, plus
  /// More (the full list). [update] refreshes an existing alert without
  /// sound or vibration.
  Future<void> showReview(PendingTransaction tx, Suggestions suggestions,
      {bool update = false});

  Future<void> cancel(int pendingId);

  /// Tells the open app (if any) that captured data changed.
  Future<void> dataChanged();
}

/// Notification wording, kept separate so it can be tested.
class AlertText {
  static String amount(double value) => formatMoney(value);

  static String reviewTitle(PendingTransaction tx) {
    final verb = tx.isDebit ? 'paid' : 'received';
    final payee = tx.merchant == null ? '' : ' · ${tx.merchant}';
    return '${amount(tx.amount)} $verb$payee';
  }

  static String reviewBody(PendingTransaction tx, {String? usual}) {
    if (usual != null) return 'Usually $usual. Tap a category, or More for all.';
    return tx.isDebit
        ? 'What was this for? Pick a category, or More for all.'
        : 'Where did this come from? Pick a source, or More for all.';
  }
}
