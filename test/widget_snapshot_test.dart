import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/pending_transaction.dart';
import 'package:expense_tracker/services/widgets/widget_snapshot.dart';
import 'package:expense_tracker/utils/analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 5, 18);
  Expense spend(double amount, String category, {int day = 2, int month = 10}) =>
      Expense(amount: amount, category: category, date: DateTime(2026, month, day));
  final categories = [
    ExpenseCategory(id: 1, name: 'Groceries', emoji: 'icon:local_grocery_store', colorValue: 0xFF2ECC71),
    ExpenseCategory(id: 2, name: 'Food', emoji: 'icon:restaurant', colorValue: 0xFFFF6B6B),
  ];

  Map<String, Object?> build({List<PendingTransaction> pending = const [], List<Expense>? expenses}) =>
      WidgetSnapshot.build(
        pending: pending,
        buttons: {for (final p in pending) p.id!: ['Food', 'Groceries']},
        expenses: expenses ?? [spend(600, 'Groceries'), spend(300, 'Food'), spend(100, 'Bills'), spend(50, 'Food', month: 9)],
        categories: categories,
        now: now,
      );

  test('waiting payments come with their title, time and two buttons', () {
    final snapshot = build(pending: [
      PendingTransaction(
          id: 7, amount: 340, type: 'debit', merchant: 'Swiggy', rawMessage: 'x', sender: 'AX-HDFCBK',
          confidence: 100, detectedAt: DateTime(2026, 10, 5, 14, 15)),
    ]);
    final payment = (snapshot['pending'] as List).single as Map;
    expect(payment['id'], 7);
    expect(payment['title'], '₹340 paid · Swiggy');
    expect(payment['time'], '5 Oct · 2:15 PM');
    expect(payment['buttons'], ['Food', 'Groceries']);
  });

  test('month pace and categories with shares and colors', () {
    final snapshot = build();
    expect(snapshot['month'], 'October');
    expect(snapshot['spent'], '₹1,000');
    expect((snapshot['thisMonth'] as List).length, 5); // 1st to 5th
    expect(snapshot['lastMonth'], isNotEmpty);
    final top = (snapshot['categories'] as List).first as Map;
    expect(top['name'], 'Groceries');
    expect(top['percent'], '60%');
    expect(top['color'], 0xFF2ECC71);
  });

  test('"N more" rows sum up whatever does not fit', () {
    final more = build()['more'] as List;
    expect((more[1] as Map)['name'], '2 more');
    expect((more[1] as Map)['amount'], '₹400');
    expect((more[1] as Map)['percent'], '40%');
  });

  test('the pace chart gets a round scale and the dates of the month', () {
    final snapshot = build();
    final top = snapshot['axisTop'] as double;
    final highest = [...(snapshot['thisMonth'] as List), ...(snapshot['lastMonth'] as List)]
        .cast<double>()
        .reduce((a, b) => a > b ? a : b);
    expect(top, greaterThanOrEqualTo(highest));
    expect((snapshot['axisLabels'] as List).last, '₹0');
    expect(snapshot['dayLabels'], ['1 Oct', '16', '31 Oct']);
  });

  test('niceCeiling rounds up to 1, 2 or 5 times a power of ten', () {
    expect(niceCeiling(8523), 10000);
    expect(niceCeiling(10000), 10000);
    expect(niceCeiling(1250), 2000);
    expect(niceCeiling(340), 500);
    expect(niceCeiling(0), 1000);
  });

  test('budgets: the monthly one on the pace widget, category ones on their rows', () {
    final snapshot = WidgetSnapshot.build(
      pending: const [],
      buttons: const {},
      expenses: [spend(600, 'Groceries'), spend(400, 'Food')],
      categories: categories,
      now: now,
      budgets: const [
        Budget(category: Budget.overall, amount: 25000, fromMonth: '2026-10'),
        Budget(category: 'Groceries', amount: 6000, fromMonth: '2026-10'),
      ],
    );
    expect(snapshot['budget'], '₹24,000 left of ₹25,000');
    final rows = (snapshot['categories'] as List).cast<Map>();
    expect(rows.firstWhere((r) => r['name'] == 'Groceries')['budget'], '₹6K');
    expect(rows.firstWhere((r) => r['name'] == 'Food').containsKey('budget'), isFalse);
    expect(rows.firstWhere((r) => r['name'] == 'Food')['amount'], '₹400');
    expect(build().containsKey('budget'), isFalse);
  });

  test('a month with no spending says so', () {
    expect(build(expenses: [])['pace'], 'Your spending this month will show up here');
  });
}
