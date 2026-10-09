import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database_helper.dart';
import '../models/budget.dart';
import '../services/budgets/budget_check.dart';

/// Every budget row (the history) plus the shared alert setting.
class BudgetData {
  final List<Budget> rows;
  final BudgetAlertSettings alerts;

  /// The user closed Home's "Set a monthly budget" card.
  final bool promptDismissed;

  const BudgetData({required this.rows, required this.alerts, required this.promptDismissed});

  List<Budget> activeIn(DateTime month) => budgetsIn(rows, month);

  Budget? overallIn(DateTime month) => activeIn(month).where((b) => b.isOverall).firstOrNull;
}

final budgetProvider = AsyncNotifierProvider<BudgetNotifier, BudgetData>(BudgetNotifier.new);

class BudgetNotifier extends AsyncNotifier<BudgetData> {
  static const _promptKey = 'budget_prompt_dismissed';
  final _db = DatabaseHelper();

  @override
  Future<BudgetData> build() async => BudgetData(
        rows: await _db.getBudgets(),
        alerts: await BudgetCheck.loadAlertSettings(_db),
        promptDismissed: await _db.getSetting(_promptKey) == 'true',
      );

  /// Sets [category]'s budget ([Budget.overall] for the monthly one) from
  /// this month on; a null [amount] removes it from this month on.
  Future<void> setBudget(String category, double? amount) async {
    await _db.setBudget(category, amount, DateTime.now());
    ref.invalidateSelf();
    await future;
  }

  Future<void> setAlerts(BudgetAlertSettings alerts) async {
    await _db.setSetting(BudgetAlertSettings.enabledKey, '${alerts.enabled}');
    await _db.setSetting(BudgetAlertSettings.firstKey, '${alerts.first}');
    await _db.setSetting(BudgetAlertSettings.secondKey, '${alerts.second}');
    ref.invalidateSelf();
    await future;
  }

  Future<void> dismissPrompt() async {
    await _db.setSetting(_promptKey, 'true');
    ref.invalidateSelf();
    await future;
  }
}
