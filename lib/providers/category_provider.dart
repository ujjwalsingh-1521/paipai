import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/category.dart';
import 'expense_provider.dart';

final categoryProvider =
    AsyncNotifierProvider<CategoryNotifier, List<ExpenseCategory>>(
        CategoryNotifier.new);

class CategoryNotifier extends AsyncNotifier<List<ExpenseCategory>> {
  final _db = DatabaseHelper();

  @override
  Future<List<ExpenseCategory>> build() => _db.getAllCategories();

  /// An error to show if [name] is taken ("Food" and "food" count as the
  /// same), or null if it's free. [exceptId] is the category being renamed.
  String? nameError(String name, {int? exceptId}) =>
      duplicateNameError(state.valueOrNull ?? [], name, exceptId: exceptId);

  Future<void> addCategory(ExpenseCategory category) async {
    await _db.insertCategory(category);
    state = AsyncData(await _db.getAllCategories());
  }

  /// Renaming also renames it on existing expenses and learned merchants.
  Future<void> updateCategory(
      ExpenseCategory category, String oldName) async {
    await _db.updateCategory(category, oldName);
    state = AsyncData(await _db.getAllCategories());
    _refreshLinkedData();
  }

  /// Moves the category's expenses (and learned merchants) to [moveTo]
  /// before deleting it.
  Future<void> deleteCategory(ExpenseCategory category, String moveTo) async {
    await _db.deleteCategoryMovingTo(category, moveTo);
    state = AsyncData(await _db.getAllCategories());
    _refreshLinkedData();
  }

  Future<int> usageCount(String name) => _db.countExpensesIn(name);

  void _refreshLinkedData() {
    ref.invalidate(expenseProvider);
  }
}

/// Shared by expense categories and income sources.
String? duplicateNameError(List<ExpenseCategory> existing, String name,
    {int? exceptId}) {
  final wanted = name.trim().toLowerCase();
  if (wanted.isEmpty) return 'Enter a name';
  final taken = existing.any(
      (c) => c.id != exceptId && c.name.trim().toLowerCase() == wanted);
  return taken ? '"${name.trim()}" already exists' : null;
}
