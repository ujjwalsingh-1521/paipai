import 'package:expense_tracker/models/balance_start.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/ledger_entry.dart';
import 'package:expense_tracker/models/split_part.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _part(int id, double amount, String category, {int? splitId}) => Expense(
    id: id, amount: amount, category: category, date: DateTime(2026, 10, 5, 18), payee: 'DMart', splitId: splitId);

void main() {
  group('split rules', () {
    test('the first part takes whatever is left', () {
      final parts = withRemainder(3000, [
        const SplitPart('Groceries', 0),
        const SplitPart('Snacks', 400),
        const SplitPart('Toys', 500),
      ]);
      expect(parts.map((p) => p.amount), [2100, 400, 500]);
      expect(splitError(3000, parts), isNull);
    });

    test('paise add up exactly', () {
      final parts = withRemainder(100.10, [const SplitPart('A', 0), const SplitPart('B', 33.37)]);
      expect(parts.first.amount, 66.73);
      expect(splitError(100.10, parts), isNull);
    });

    test('refuses fewer than 2 parts, empty parts, or more than the total', () {
      expect(splitError(500, withRemainder(500, [const SplitPart('A', 0)])), contains('at least 2'));
      expect(splitError(500, withRemainder(500, [const SplitPart('A', 0), const SplitPart('B', 0)])),
          contains('every part'));
      expect(splitError(500, withRemainder(500, [const SplitPart('A', 0), const SplitPart('B', 600)])),
          contains('more than ₹500'));
    });
  });

  group('split payments in lists', () {
    final parts = [_part(10, 2100, 'Groceries', splitId: 10), _part(11, 400, 'Snacks', splitId: 10), _part(12, 500, 'Toys', splitId: 10)];

    test('the parts show as one payment, largest first', () {
      final entries = LedgerEntry.merge([...parts, _part(9, 50, 'Food')], []);
      expect(entries.length, 2);
      final split = entries.firstWhere((e) => e.isSplit);
      expect(split.amount, 3000);
      expect(split.id, 10);
      expect(split.label, 'Groceries, Toys, Snacks');
      expect(split.amountIn('Snacks'), 400);
      expect(split.labels, containsAll(['Groceries', 'Snacks', 'Toys']));
    });

    test('splitting an older payment does not move the balance', () {
      // Balance set after payment 10 existed; the split added rows 11 and 12.
      final start = BalanceStart(amount: 10000, setAt: DateTime(2026, 10, 5), lastExpenseId: 10, lastIncomeId: 0);
      expect(start.currentBalance(parts, []), 10000);
      expect(start.currentBalance([...parts, _part(13, 99, 'Food')], []), 9901);
    });
  });
}
