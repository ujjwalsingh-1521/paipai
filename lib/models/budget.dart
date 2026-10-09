/// A monthly spending limit: the overall one ([category] is
/// [Budget.overall]) or one category's. Rows form a history: each applies
/// from [fromMonth] until a later row for the same category, and a null
/// [amount] means the budget was removed from that month on.
class Budget {
  static const overall = '';

  final int? id;
  final String category;
  final double? amount;

  /// 'YYYY-MM'; text order is month order.
  final String fromMonth;

  const Budget({this.id, required this.category, required this.amount, required this.fromMonth});

  bool get isOverall => category == overall;

  static String monthKey(DateTime month) => '${month.year}-${month.month.toString().padLeft(2, '0')}';

  Map<String, Object?> toMap() =>
      {'id': id, 'category': category, 'amount': amount, 'from_month': fromMonth};

  factory Budget.fromMap(Map<String, Object?> map) => Budget(
        id: map['id'] as int?,
        category: map['category'] as String,
        amount: (map['amount'] as num?)?.toDouble(),
        fromMonth: map['from_month'] as String,
      );
}

/// The budgets in force in [month]: for each category, its latest row
/// starting on or before that month, unless that row removed it. The
/// overall budget (if any) comes first, then categories by name.
List<Budget> budgetsIn(List<Budget> rows, DateTime month) {
  final key = Budget.monthKey(month);
  final latest = <String, Budget>{};
  for (final row in rows) {
    if (row.fromMonth.compareTo(key) > 0) continue;
    final current = latest[row.category];
    if (current == null || row.fromMonth.compareTo(current.fromMonth) > 0) latest[row.category] = row;
  }
  final active = latest.values.where((b) => (b.amount ?? 0) > 0).toList()
    ..sort((a, b) => a.isOverall ? -1 : b.isOverall ? 1 : a.category.compareTo(b.category));
  return active;
}

/// The one alert setting shared by every budget: on or off, and the two
/// warning percentages (an "over budget" alert always comes too).
class BudgetAlertSettings {
  static const defaultFirst = 80;
  static const defaultSecond = 90;

  /// The percentages offered for warnings.
  static const choices = [50, 60, 70, 75, 80, 85, 90, 95];

  static const enabledKey = 'budget_alerts';
  static const firstKey = 'budget_warn_1';
  static const secondKey = 'budget_warn_2';

  final bool enabled;
  final int first;
  final int second;

  const BudgetAlertSettings({this.enabled = true, this.first = defaultFirst, this.second = defaultSecond});

  /// From stored settings; anything missing or invalid falls back to the defaults.
  factory BudgetAlertSettings.decode({String? enabled, String? first, String? second}) {
    final low = int.tryParse(first ?? '') ?? defaultFirst;
    final high = int.tryParse(second ?? '') ?? defaultSecond;
    final valid = low >= 1 && high <= 99 && low < high;
    return BudgetAlertSettings(
      enabled: enabled != 'false',
      first: valid ? low : defaultFirst,
      second: valid ? high : defaultSecond,
    );
  }
}
