import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/pending_transaction.dart';
import '../models/split_part.dart';
import '../services/capture/capture_channel.dart';
import '../services/capture/capture_service.dart';
import 'expense_provider.dart';
import 'income_provider.dart';

/// Captured payments still waiting for a category.
final pendingTransactionProvider = AsyncNotifierProvider<
    PendingTransactionNotifier, List<PendingTransaction>>(
    PendingTransactionNotifier.new);

class PendingTransactionNotifier
    extends AsyncNotifier<List<PendingTransaction>> {
  final _db = DatabaseHelper();
  final _capture = CaptureService(alerts: NativeCaptureAlerts());

  @override
  Future<List<PendingTransaction>> build() =>
      _db.getAllPendingTransactions(unprocessedOnly: true);

  Future<void> categorize(int id, String category) async {
    await _capture.categorize(id, category);
    ref.invalidate(expenseProvider);
    ref.invalidate(incomeProvider);
    await refresh();
  }

  /// Every category for [tx], best guess first (see CaptureService).
  Future<Suggestions> suggestionsFor(PendingTransaction tx) =>
      _capture.suggestionsFor(tx);

  Future<void> categorizeSplit(int id, List<SplitPart> parts) async {
    await _capture.categorizeSplit(id, parts);
    ref.invalidate(expenseProvider);
    await refresh();
  }

  /// "Not a payment".
  Future<void> dismiss(int id) async {
    await _capture.dismiss(id);
    await refresh();
  }

  /// "These were 2 payments".
  Future<void> splitOff(int id) async {
    await _capture.splitOff(id);
    await refresh();
  }

  Future<void> refresh() async => await latest();

  /// Reloads from the database (the background engine may have added some)
  /// and returns the list, newest first.
  Future<List<PendingTransaction>> latest() async {
    final pending = await _db.getAllPendingTransactions(unprocessedOnly: true);
    state = AsyncData(pending);
    return pending;
  }
}
