import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/category.dart';
import 'category_provider.dart';
import 'income_provider.dart';

final incomeSourceProvider =
    AsyncNotifierProvider<IncomeSourceNotifier, List<ExpenseCategory>>(
        IncomeSourceNotifier.new);

class IncomeSourceNotifier extends AsyncNotifier<List<ExpenseCategory>> {
  final _db = DatabaseHelper();

  @override
  Future<List<ExpenseCategory>> build() => _db.getAllIncomeSources();

  String? nameError(String name, {int? exceptId}) =>
      duplicateNameError(state.valueOrNull ?? [], name, exceptId: exceptId);

  Future<void> addSource(ExpenseCategory source) async {
    await _db.insertIncomeSource(source);
    state = AsyncData(await _db.getAllIncomeSources());
  }

  /// Renaming also renames it on existing income and learned payers.
  Future<void> updateSource(
      ExpenseCategory source, String oldName) async {
    await _db.updateIncomeSource(source, oldName);
    state = AsyncData(await _db.getAllIncomeSources());
    _refreshLinkedData();
  }

  Future<void> deleteSource(ExpenseCategory source, String moveTo) async {
    await _db.deleteIncomeSourceMovingTo(source, moveTo);
    state = AsyncData(await _db.getAllIncomeSources());
    _refreshLinkedData();
  }

  Future<int> usageCount(String name) => _db.countIncomeFrom(name);

  void _refreshLinkedData() {
    ref.invalidate(incomeProvider);
  }
}
