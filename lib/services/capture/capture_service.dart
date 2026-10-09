import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../db/database_helper.dart';
import '../../models/expense.dart';
import '../../models/income.dart';
import '../../models/pending_transaction.dart';
import '../../models/split_part.dart';
import 'capture_alerts.dart';
import 'merchant_normalizer.dart';
import 'parsed_payment.dart';
import 'payment_matcher.dart';
import 'payment_parser.dart';

/// Turns payment notifications into reviewable transactions, and applies
/// the user's answers. Nothing is ever filed without the user choosing:
/// a merchant's past choices only decide which categories are suggested. Runs in the background capture engine (notifications
/// arrive there) and in the app (in-app review, test payments).
class CaptureService {
  /// Category buttons on a notification (Android shows at most 3 actions;
  /// the third is More).
  static const notificationChoices = 2;
  static const _hashRetention = Duration(days: 30);

  final DatabaseHelper _db;
  final CaptureAlerts _alerts;

  // Notifications are handled one at a time, so two alerts for the same
  // payment can't both be recorded before either sees the other.
  Future<void> _queue = Future.value();

  CaptureService({required this._alerts, DatabaseHelper? db})
      : _db = db ?? DatabaseHelper();

  Future<void> handleNotification(NotificationInput input) {
    final next = _queue.then((_) => _handle(input));
    _queue = next.catchError((_) {});
    return next;
  }

  Future<void> _handle(NotificationInput input) async {
    final payment = PaymentParser.parse(input);
    if (payment == null) return;
    // Android re-posts notifications (updates, regrouping); skip repeats.
    final fingerprint = _fingerprint(input);
    if (await _db.isSmsProcessed(fingerprint)) return;
    final since = input.postedAt.subtract(PaymentMatcher.lookback);
    final recent = await _db.getCapturesSince(since);
    final existing = PaymentMatcher.findSamePayment(payment, recent);
    if (existing != null) {
      await _mergeInto(existing, payment);
    } else {
      await _recordNew(payment);
    }
    // Marked only after saving, so a failure part-way doesn't lose it.
    await _db.markSmsProcessed(fingerprint);
    await _db.pruneProcessedHashes(DateTime.now().subtract(_hashRetention));
    await _alerts.dataChanged();
  }

  static String _fingerprint(NotificationInput input) => sha256
      .convert(utf8.encode('${input.app}|${input.messageId}|${input.text}'))
      .toString();

  Future<void> _mergeInto(PendingTransaction existing, ParsedPayment payment) async {
    final merged = PaymentMatcher.merge(existing, payment);
    await _db.updatePendingTransaction(merged);
    if (!merged.isProcessed) {
      await _alerts.showReview(merged, await suggestionsFor(merged), update: true);
    }
  }

  Future<void> _recordNew(ParsedPayment payment) async {
    final pending = _toPending(payment);
    final id = await _db.insertPendingTransaction(pending);
    final saved = pending.copyWith(id: id);
    await _alerts.showReview(saved, await suggestionsFor(saved));
  }

  PendingTransaction _toPending(ParsedPayment payment) => PendingTransaction(
        amount: payment.amount,
        type: payment.direction.name,
        merchant: payment.payee,
        upiRef: payment.reference,
        accountTail: payment.accountTail,
        rawMessage: payment.source.text,
        sender: payment.source.title,
        confidence: 100,
        detectedAt: payment.source.postedAt,
        sourceApp: payment.source.app,
      );

  /// Every category (or income source), best guess first: what was picked
  /// for this payee before (most often, then most recently), then the
  /// user's most-used ones lately, then the rest.
  Future<Suggestions> suggestionsFor(PendingTransaction tx) async {
    final income = !tx.isDebit;
    final all = income ? await _db.getAllIncomeSources() : await _db.getAllCategories();
    // Without history, use the order defaults were created in (Food,
    // Transport... / Salary, ...), not alphabetical.
    final byCreation = [...all]..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
    final since = DateTime.now().subtract(const Duration(days: 90));
    return Suggestions.rank(
      payeeHistory: await _payeeHistory(tx, income: income),
      recentTop: await _db.topCategoryNames(income: income, since: since, limit: 5),
      all: [for (final c in byCreation) c.name],
    );
  }

  /// Categories picked for this payee before, newest first.
  Future<List<String>> _payeeHistory(PendingTransaction tx, {required bool income}) async {
    final merchant = tx.merchant;
    if (merchant == null) return const [];
    final key = normalizeMerchant(merchant);
    final choices = await _db.capturedChoices(income: income);
    return [
      for (final choice in choices)
        if (normalizeMerchant(choice.merchant) == key) choice.category,
    ];
  }

  // --- Answers from the notification buttons or the in-app sheet ---

  Future<void> categorize(int pendingId, String category) async {
    final tx = await _db.getPendingTransaction(pendingId);
    if (tx == null || tx.isProcessed) return;
    await _saveAs(tx, category);
    await _alerts.cancel(pendingId);
    await _alerts.dataChanged();
  }

  /// Saves a captured payment split across categories ([parts] already
  /// add up to its amount; see splitError).
  Future<void> categorizeSplit(int pendingId, List<SplitPart> parts) async {
    final tx = await _db.getPendingTransaction(pendingId);
    if (tx == null || tx.isProcessed || !tx.isDebit) return;
    final error = splitError(tx.amount, parts);
    if (error != null) throw ArgumentError(error);
    final payment = Expense(
        amount: tx.amount, category: parts.first.category, date: tx.detectedAt, payee: tx.merchant);
    final leadId = await _db.saveSplit(payment, parts);
    await _db.markTransactionProcessed(pendingId, expenseId: leadId);
    await _alerts.cancel(pendingId);
    await _alerts.dataChanged();
  }

  /// "Not a payment": kept (as handled) so later alerts for it stay silent.
  Future<void> dismiss(int pendingId) async {
    await _db.markTransactionProcessed(pendingId);
    await _alerts.cancel(pendingId);
    await _alerts.dataChanged();
  }

  /// "These were 2 payments": splits one merged alert into two to review.
  Future<void> splitOff(int pendingId) async {
    final tx = await _db.getPendingTransaction(pendingId);
    if (tx == null) return;
    final remaining = tx.seenCount > 1 ? tx.seenCount - 1 : 1;
    await _db.updatePendingTransaction(
        tx.copyWith(seenCount: remaining, maybeMultiple: false));
    await _db.insertPendingTransaction(PendingTransaction(
      amount: tx.amount,
      type: tx.type,
      merchant: tx.merchant,
      accountTail: tx.accountTail,
      rawMessage: tx.rawMessage,
      sender: tx.sender,
      confidence: tx.confidence,
      detectedAt: tx.detectedAt,
      sourceApp: tx.sourceApp,
    ));
    await _alerts.dataChanged();
  }

  Future<void> _saveAs(PendingTransaction tx, String category) async {
    final id = tx.id!;
    if (tx.isDebit) {
      final expenseId = await _db.insertExpense(Expense(
          amount: tx.amount, category: category, date: tx.detectedAt, payee: tx.merchant));
      await _db.markTransactionProcessed(id, expenseId: expenseId);
    } else {
      final incomeId = await _db.insertIncome(Income(
          amount: tx.amount, source: category, date: tx.detectedAt, payee: tx.merchant));
      await _db.markTransactionProcessed(id, incomeId: incomeId);
    }
  }
}

/// Ordered category names for one payment. [usual] is set when the payee
/// has history, so the app can pre-select it.
class Suggestions {
  final List<String> ordered;
  final String? usual;

  const Suggestions(this.ordered, {this.usual});

  /// [payeeHistory] is newest first; names no longer in [all] are dropped.
  factory Suggestions.rank({
    required List<String> payeeHistory,
    required List<String> recentTop,
    required List<String> all,
  }) {
    final existing = all.toSet();
    final counts = <String, int>{};
    for (final name in payeeHistory) {
      if (existing.contains(name)) counts[name] = (counts[name] ?? 0) + 1;
    }
    // Map keeps first-seen (most recent) order; a stable sort by count
    // leaves ties in that order.
    final forPayee = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    // "Other" next to the More button reads like More itself, so it is
    // only suggested where it really is the usual choice.
    final ordered = {
      ...forPayee,
      ...recentTop.where((name) => existing.contains(name) && name != otherCategory),
      ...all.where((name) => name != otherCategory),
      ...all,
    }.toList();
    return Suggestions(ordered, usual: forPayee.firstOrNull);
  }

  static const otherCategory = 'Other';

  /// The buttons shown on the notification.
  List<String> get forNotification =>
      ordered.take(CaptureService.notificationChoices).toList();
}
