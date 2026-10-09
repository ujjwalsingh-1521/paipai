import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/income.dart';

final incomeProvider =
    AsyncNotifierProvider<IncomeNotifier, List<Income>>(IncomeNotifier.new);

class IncomeNotifier extends AsyncNotifier<List<Income>> {
  final _db = DatabaseHelper();

  @override
  Future<List<Income>> build() => _db.getAllIncome();

  Future<void> addIncome(Income income) async {
    await _db.insertIncome(income);
    state = AsyncData(await _db.getAllIncome());
  }

  Future<void> updateIncome(Income income) async {
    await _db.updateIncome(income);
    state = AsyncData(await _db.getAllIncome());
  }

  Future<void> deleteIncome(int id) async {
    await _db.deleteIncome(id);
    state = AsyncData(await _db.getAllIncome());
  }

  /// Re-inserts a deleted income entry with its original id (for Undo).
  Future<void> restoreIncome(Income income) => addIncome(income);
}
