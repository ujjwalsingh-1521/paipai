import 'dart:convert';

import '../utils/money.dart';
import 'expense.dart';
import 'income.dart';

/// The bank balance the user typed in, and where the entries stood at that
/// moment. Everything added afterwards moves the balance; everything that
/// existed before is already part of the typed amount.
class BalanceStart {
  final double amount;
  final DateTime setAt;
  final int lastExpenseId;
  final int lastIncomeId;

  const BalanceStart({
    required this.amount,
    required this.setAt,
    required this.lastExpenseId,
    required this.lastIncomeId,
  });

  /// Entries count by when they were added (their id), not the date on
  /// them, so anything recorded after the balance was set moves it, even
  /// if it's dated earlier that day. Splitting an older payment adds rows
  /// with new ids, so parts count by their split's first part.
  double currentBalance(List<Expense> expenses, List<Income> income) {
    final added = sumMoney(income.where((i) => (i.id ?? 0) > lastIncomeId).map((i) => i.amount));
    final spent =
        sumMoney(expenses.where((e) => e.recordedId > lastExpenseId).map((e) => e.amount));
    return roundMoney(amount + added - spent);
  }

  String encode() => jsonEncode({
        'amount': amount,
        'setAt': setAt.toIso8601String(),
        'lastExpenseId': lastExpenseId,
        'lastIncomeId': lastIncomeId,
      });

  /// Null if [text] is missing or unreadable.
  static BalanceStart? decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      return BalanceStart(
        amount: (json['amount'] as num).toDouble(),
        setAt: DateTime.parse(json['setAt'] as String),
        lastExpenseId: json['lastExpenseId'] as int,
        lastIncomeId: json['lastIncomeId'] as int,
      );
    } on Object {
      return null;
    }
  }
}
