import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../db/database_helper.dart';
import '../../models/budget.dart';
import '../../utils/analytics.dart';
import '../../utils/budgets.dart';

/// Shows a budget alert. The native one posts an Android notification;
/// tests substitute a fake.
abstract class BudgetNotifier {
  /// [id] is stable per budget, so a newer alert replaces the older one.
  Future<void> show(int id, String title, String body);
}

class NativeBudgetNotifier implements BudgetNotifier {
  static const _channel = MethodChannel('com.expense.expense_tracker/capture');

  @override
  Future<void> show(int id, String title, String body) =>
      _channel.invokeMethod('showBudgetAlert', {'id': id, 'title': title, 'text': body});
}

/// After any change: has a budget crossed a warning level this month?
/// Each level alerts once per budget per month. The level reached is saved
/// on every check, so falling back below a level (an entry deleted, the
/// budget raised) lets it alert again when crossed again.
class BudgetCheck {
  final DatabaseHelper db;
  final BudgetNotifier notifier;

  BudgetCheck({DatabaseHelper? db, BudgetNotifier? notifier})
      : db = db ?? DatabaseHelper(),
        notifier = notifier ?? NativeBudgetNotifier();

  static Future<void>? _running;
  static bool _again = false;

  /// Checks with the native notifier. Calls during a check fold into one more.
  static Future<void> run() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  static Future<void> _loop() async {
    do {
      _again = false;
      try {
        await BudgetCheck().check(DateTime.now());
      } catch (error) {
        // Alerts are a nice-to-have: never let them break saving.
        debugPrint('PaiPai budget check failed: $error');
      }
    } while (_again);
  }

  Future<void> check(DateTime now) async {
    final month = monthOf(now);
    final budgets = budgetsIn(await db.getBudgets(), month);
    if (budgets.isEmpty) return;
    final settings = await loadAlertSettings(db);
    final expenses = expensesIn(await db.getAllExpenses(), month);
    for (final budget in budgets) {
      final status = BudgetStatus.of(budget, expenses, month, now);
      await _checkOne(status, settings, month);
    }
  }

  Future<void> _checkOne(BudgetStatus status, BudgetAlertSettings settings, DateTime month) async {
    final key = levelKey(status.budget.category, month);
    final previous = int.tryParse(await db.getSetting(key) ?? '') ?? 0;
    final level = budgetLevel(status, settings);
    if (level == previous) return;
    // Saved first, so a second check running at the same time stays quiet.
    await db.setSetting(key, '$level');
    if (level > previous && settings.enabled) {
      await notifier.show(
        notificationId(status.budget.category),
        BudgetText.alertTitle(status.budget, month, level, settings),
        BudgetText.alertBody(status),
      );
    }
  }

  static String levelKey(String category, DateTime month) => 'budget_level:$category:${Budget.monthKey(month)}';

  /// Far above pending-payment ids (the payment alerts' notification ids),
  /// and the same on every run (String.hashCode isn't promised to be).
  static int notificationId(String category) =>
      1900000000 + category.codeUnits.fold(0, (hash, unit) => (hash * 31 + unit) & 0xFFFFF);

  static Future<BudgetAlertSettings> loadAlertSettings(DatabaseHelper db) async => BudgetAlertSettings.decode(
        enabled: await db.getSetting(BudgetAlertSettings.enabledKey),
        first: await db.getSetting(BudgetAlertSettings.firstKey),
        second: await db.getSetting(BudgetAlertSettings.secondKey),
      );
}
