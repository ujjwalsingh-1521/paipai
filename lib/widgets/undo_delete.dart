import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense.dart';
import '../models/income.dart';
import '../providers/expense_provider.dart';
import '../providers/income_provider.dart';

// Pass the ScaffoldMessenger captured *before* closing any sheet/dialog,
// so the Undo snackbar still has somewhere to show.

Future<void> deleteExpenseWithUndo(
    WidgetRef ref, ScaffoldMessengerState messenger, Expense expense) async {
  final notifier = ref.read(expenseProvider.notifier);
  await notifier.deleteExpense(expense.id!);
  _showUndo(messenger, 'Expense deleted', () => notifier.restoreExpense(expense));
}

Future<void> deleteIncomeWithUndo(
    WidgetRef ref, ScaffoldMessengerState messenger, Income income) async {
  final notifier = ref.read(incomeProvider.notifier);
  await notifier.deleteIncome(income.id!);
  _showUndo(messenger, 'Income deleted', () => notifier.restoreIncome(income));
}

/// Deletes every part of a split payment, with one Undo for all of them.
Future<void> deleteSplitWithUndo(
    WidgetRef ref, ScaffoldMessengerState messenger, int splitId) async {
  final notifier = ref.read(expenseProvider.notifier);
  final parts = await notifier.deleteSplit(splitId);
  _showUndo(messenger, 'Payment deleted', () => notifier.restoreSplit(parts));
}

void _showUndo(
    ScaffoldMessengerState messenger, String message, VoidCallback onUndo) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: 'UNDO', onPressed: onUndo),
    ));
}
