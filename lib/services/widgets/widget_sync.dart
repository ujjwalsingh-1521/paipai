import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../db/database_helper.dart';
import '../../models/pending_transaction.dart';
import '../capture/capture_alerts.dart';
import '../capture/capture_service.dart';
import 'widget_snapshot.dart';

/// Sends a fresh [WidgetSnapshot] to the home-screen widgets. Called after
/// anything changes (in the app, the capture engine and the More card).
/// Calls that arrive while one is running are folded into one more run.
abstract final class WidgetSync {
  static const _channel = MethodChannel('com.expense.expense_tracker/capture');
  static Future<void>? _running;
  static bool _again = false;

  static Future<void> push() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _run().whenComplete(() => _running = null);
  }

  static Future<void> _run() async {
    do {
      _again = false;
      try {
        await _channel.invokeMethod('updateWidgets', {'snapshot': jsonEncode(await _snapshot())});
      } catch (error) {
        // Widgets are a nice-to-have: never let them break saving.
        debugPrint('PaiPai widgets not updated: $error');
      }
    } while (_again);
  }

  static Future<Map<String, Object?>> _snapshot() async {
    final db = DatabaseHelper();
    final pending = await db.getAllPendingTransactions(unprocessedOnly: true);
    final service = CaptureService(alerts: _NoAlerts(), db: db);
    return WidgetSnapshot.build(
      pending: pending,
      buttons: {
        for (final tx in pending.take(WidgetSnapshot.maxPending))
          tx.id!: (await service.suggestionsFor(tx)).forNotification,
      },
      expenses: await db.getAllExpenses(),
      categories: await db.getAllCategories(),
      now: DateTime.now(),
      budgets: await db.getBudgets(),
    );
  }
}

/// Suggestions only read the database; nothing is shown from here.
class _NoAlerts implements CaptureAlerts {
  @override
  Future<void> showReview(PendingTransaction tx, Suggestions suggestions, {bool update = false}) async {}

  @override
  Future<void> cancel(int pendingId) async {}

  @override
  Future<void> dataChanged() async {}
}
