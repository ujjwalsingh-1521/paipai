import 'package:expense_tracker/models/balance_start.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/income.dart';
import 'package:expense_tracker/providers/category_provider.dart';
import 'package:expense_tracker/utils/analytics.dart';
import 'package:expense_tracker/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _expense(int id, double amount, {DateTime? date}) =>
    Expense(id: id, amount: amount, category: 'Food', date: date ?? DateTime(2026, 10, 3));

Income _income(int id, double amount, {DateTime? date}) =>
    Income(id: id, amount: amount, source: 'Salary', date: date ?? DateTime(2026, 10, 3));

void main() {
  group('bank balance', () {
    final start = BalanceStart(
      amount: 10000,
      setAt: DateTime(2026, 10, 3, 9),
      lastExpenseId: 5,
      lastIncomeId: 2,
    );

    test('entries that existed when it was set are already in the balance', () {
      expect(start.currentBalance([_expense(4, 500), _expense(5, 200)], [_income(2, 900)]), 10000);
    });

    test('later income adds and later expenses subtract', () {
      final expenses = [_expense(5, 200), _expense(6, 250), _expense(9, 99.5)];
      final income = [_income(3, 50000)];
      expect(start.currentBalance(expenses, income), 10000 + 50000 - 250 - 99.5);
    });

    test('counts entries added later even if dated earlier', () {
      final backdated = _expense(7, 300, date: DateTime(2026, 9, 1));
      expect(start.currentBalance([backdated], []), 9700);
    });

    test('payments captured before it was set never move it, even labelled later', () {
      // Imported from old SMS: ₹300 expense (split into 2 parts) and ₹1,000 income.
      final split = [
        Expense(id: 8, amount: 200, category: 'Food', date: DateTime(2026, 9, 20), splitId: 8),
        Expense(id: 9, amount: 100, category: 'Shopping', date: DateTime(2026, 9, 20), splitId: 8),
      ];
      const earlier = EarlierPayments(expenseIds: {8}, incomeIds: {4});
      final balance = start.currentBalance([...split, _expense(10, 50)], [_income(4, 1000)], earlier: earlier);
      expect(balance, 9950);
    });

    test('can go below zero', () {
      expect(start.currentBalance([_expense(6, 12000)], []), -2000);
    });

    test('survives saving and loading', () {
      final loaded = BalanceStart.decode(start.encode())!;
      expect(loaded.amount, 10000);
      expect(loaded.lastExpenseId, 5);
      expect(loaded.setAt, DateTime(2026, 10, 3, 9));
      expect(BalanceStart.decode(null), isNull);
      expect(BalanceStart.decode('not json'), isNull);
    });
  });

  group('category names', () {
    final existing = [
      ExpenseCategory(id: 1, name: 'Food', emoji: '🍔', colorValue: 0),
      ExpenseCategory(id: 2, name: 'Transport', emoji: '🚗', colorValue: 0),
    ];

    test('rejects a name that differs only in case or spaces', () {
      expect(duplicateNameError(existing, 'food'), contains('already exists'));
      expect(duplicateNameError(existing, '  FOOD '), contains('already exists'));
    });

    test('allows new names and renaming a category to itself', () {
      expect(duplicateNameError(existing, 'Gym'), isNull);
      expect(duplicateNameError(existing, 'food', exceptId: 1), isNull);
    });

    test('rejects an empty name', () {
      expect(duplicateNameError(existing, '   '), 'Enter a name');
    });
  });

  group('money', () {
    test('rounds to paise and hides float noise in totals', () {
      expect(roundMoney(250.004), 250.0);
      expect(roundMoney(0.1 + 0.2), 0.3);
      expect(sumMoney([0.1, 0.2, 0.3]), 0.6);
    });

    test('one way of writing amounts', () {
      expect(formatMoney(899), '₹899');
      expect(formatMoney(899.5), '₹899.50');
      expect(formatMoney(123450), '₹1,23,450');
    });
  });

  group('insights', () {
    Expense spend(int day, double amount, {int month = 10, String category = 'Food'}) =>
        Expense(id: day * 100 + month, amount: amount, category: category, date: DateTime(2026, month, day, 12));

    test('pace compares with last month by the same day', () {
      final all = [spend(1, 100), spend(3, 200), spend(2, 50, month: 9), spend(20, 900, month: 9)];
      final pace = MonthPace.of(all, DateTime(2026, 10), DateTime(2026, 10, 3, 18));
      expect(pace.spent, 300);
      expect(pace.lastMonthSoFar, 50);
      expect(pace.lastMonthTotal, 950);
      expect(pace.difference, 250);
      expect(pace.thisMonth.length, 31);
    });

    test('a finished month counts all its days', () {
      final pace = MonthPace.of([spend(30, 10, month: 9)], DateTime(2026, 9), DateTime(2026, 10, 3));
      expect(pace.daysElapsed, 30);
      expect(pace.spent, 10);
    });

    test('categories ranked with their share', () {
      final totals = categoryTotals([
        spend(1, 899, category: 'Shopping'),
        spend(2, 450, category: 'Food'),
        spend(3, 120, category: 'Food'),
        spend(3, 120, category: 'Other'),
      ]);
      expect(totals.map((t) => t.name), ['Shopping', 'Food', 'Other']);
      expect(totals[1].amount, 570);
      expect(totals.first.share, closeTo(899 / 1589, 0.0001));
    });

    test('daily totals land on their day', () {
      final daily = dailyTotals([spend(3, 200), spend(3, 50), spend(9, 1, month: 9)], DateTime(2026, 10));
      expect(daily[2], 250);
      expect(daily.where((d) => d > 0).length, 1);
    });
  });
}
