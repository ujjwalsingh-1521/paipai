import '../utils/money.dart';

class Expense {
  final int? id;
  final double amount;
  final String category;
  final DateTime date;
  /// Who was paid (from a captured payment, or typed).
  final String? payee;

  /// The user's own note; separate from [payee].
  final String? notes;

  /// Set on every part of a split payment: the id of its first part (the
  /// one a captured payment is linked to). Null for ordinary expenses.
  final int? splitId;

  Expense({
    this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.payee,
    this.notes,
    this.splitId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': roundMoney(amount),
      'category': category,
      'date': date.toIso8601String(),
      'payee': payee,
      'notes': notes,
      'split_id': splitId,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      date: DateTime.parse(map['date'] as String),
      payee: map['payee'] as String?,
      notes: map['notes'] as String?,
      splitId: map['split_id'] as int?,
    );
  }
}

extension ExpenseSplit on Expense {
  bool get isSplitPart => splitId != null;

  /// The id that says when this payment was recorded: a split's parts all
  /// count as their first part (splitting an old payment adds new rows).
  int get recordedId => splitId ?? id ?? 0;
}
