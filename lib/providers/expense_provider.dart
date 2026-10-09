import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/expense.dart';
import '../models/split_part.dart';

final expenseProvider =
    AsyncNotifierProvider<ExpenseNotifier, List<Expense>>(ExpenseNotifier.new);

class ExpenseNotifier extends AsyncNotifier<List<Expense>> {
  final _db = DatabaseHelper();

  @override
  Future<List<Expense>> build() => _db.getAllExpenses();

  Future<void> addExpense(Expense expense) async {
    await _db.insertExpense(expense);
    state = AsyncData(await _db.getAllExpenses());
  }

  Future<void> updateExpense(Expense expense) async {
    await _db.updateExpense(expense);
    state = AsyncData(await _db.getAllExpenses());
  }

  Future<void> deleteExpense(int id) async {
    await _db.deleteExpense(id);
    state = AsyncData(await _db.getAllExpenses());
  }

  /// Re-inserts a deleted expense with its original id (for Undo).
  Future<void> restoreExpense(Expense expense) => addExpense(expense);

  /// Saves [payment] split into [parts] (a new payment when its id is null).
  Future<void> saveSplit(Expense payment, List<SplitPart> parts) async {
    await _db.saveSplit(payment, parts);
    state = AsyncData(await _db.getAllExpenses());
  }

  Future<void> unsplit(int splitId) async {
    await _db.unsplit(splitId);
    state = AsyncData(await _db.getAllExpenses());
  }

  /// Deletes the whole split payment; returns its parts for Undo.
  Future<List<Expense>> deleteSplit(int splitId) async {
    final parts = await _db.deleteSplit(splitId);
    state = AsyncData(await _db.getAllExpenses());
    return parts;
  }

  Future<void> restoreSplit(List<Expense> parts) async {
    for (final part in parts) {
      await _db.insertExpense(part);
    }
    state = AsyncData(await _db.getAllExpenses());
  }
}
