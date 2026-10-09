import 'package:expense_tracker/db/database_helper.dart';
import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/split_part.dart';
import 'package:expense_tracker/services/budgets/budget_check.dart';
import 'package:expense_tracker/utils/budgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeNotifier implements BudgetNotifier {
  final shown = <String>[];

  @override
  Future<void> show(int id, String title, String body) async => shown.add(title);
}

Expense _spend(double amount, String category, {int day = 2, int month = 10}) =>
    Expense(amount: amount, category: category, date: DateTime(2026, month, day));

Budget _budget(double? amount, {String category = Budget.overall, String from = '2026-10'}) =>
    Budget(category: category, amount: amount, fromMonth: from);

void main() {
  final october = DateTime(2026, 10);
  final tenth = DateTime(2026, 10, 10, 12);

  group('which budget applies in a month', () {
    test('a budget repeats until changed; past months keep their amount', () {
      final rows = [_budget(20000, from: '2026-09'), _budget(25000, from: '2026-11')];
      expect(budgetsIn(rows, DateTime(2026, 9)).single.amount, 20000);
      expect(budgetsIn(rows, october).single.amount, 20000);
      expect(budgetsIn(rows, DateTime(2027, 2)).single.amount, 25000);
      expect(budgetsIn(rows, DateTime(2026, 8)), isEmpty);
    });

    test('removing a budget stops it from that month on', () {
      final rows = [_budget(6000, category: 'Food', from: '2026-09'), _budget(null, category: 'Food', from: '2026-10')];
      expect(budgetsIn(rows, DateTime(2026, 9)), hasLength(1));
      expect(budgetsIn(rows, october), isEmpty);
    });

    test('the monthly budget comes first, then categories by name', () {
      final rows = [_budget(4000, category: 'Shopping'), _budget(25000), _budget(6000, category: 'Food')];
      expect(budgetsIn(rows, october).map((b) => b.category), ['', 'Food', 'Shopping']);
    });
  });

  group('status', () {
    test('only that category counts, split parts in their own category', () {
      final food = _budget(6000, category: 'Food');
      final expenses = [_spend(2000, 'Food'), _spend(500, 'Shopping'), _spend(300, 'Food')];
      expect(BudgetStatus.of(food, expenses, october, tenth).spent, 2300);
      expect(BudgetStatus.of(_budget(25000), expenses, october, tenth).spent, 2800);
    });

    test('on track, ahead of pace, over', () {
      // Day 10 of 31: an even pace for ₹31,000 is ₹10,000.
      final budget = _budget(31000);
      BudgetPace pace(double spent) => BudgetStatus.of(budget, [_spend(spent, 'Food')], october, tenth).pace;
      expect(pace(9000), BudgetPace.onTrack);
      expect(pace(12000), BudgetPace.ahead);
      expect(pace(31500), BudgetPace.over);
    });

    test('a finished month is never "ahead"', () {
      final status = BudgetStatus.of(_budget(25000), [_spend(24000, 'Food')], DateTime(2026, 9), tenth);
      expect(status.isFinished, isTrue);
      expect(status.pace, BudgetPace.onTrack);
      expect(BudgetText.statusLine(status), '96% used');
    });

    test('status lines', () {
      final budget = _budget(31000);
      String line(double spent) => BudgetText.statusLine(BudgetStatus.of(budget, [_spend(spent, 'Food')], october, tenth));
      expect(line(9000), '29% used · 21 days left · on track');
      expect(line(12000), '39% used · ₹2,000 ahead of pace');
      expect(line(32200), '104% used · 21 days left');
    });
  });

  group('alert levels', () {
    const settings = BudgetAlertSettings();
    int level(double spent) => budgetLevel(BudgetStatus.of(_budget(25000), [_spend(spent, 'Food')], october, tenth), settings);

    test('80%, 90% and over', () {
      expect(level(19000), 0);
      expect(level(20000), 1);
      expect(level(22500), 2);
      expect(level(25000), 2); // exactly used up is not over
      expect(level(25001), 3);
    });

    test('bad stored settings fall back to 80/90', () {
      final s = BudgetAlertSettings.decode(first: '95', second: '70');
      expect([s.first, s.second], [80, 90]);
      expect(BudgetAlertSettings.decode(enabled: 'false').enabled, isFalse);
    });

    test('alert wording', () {
      final status = BudgetStatus.of(_budget(25000), [_spend(20000, 'Food')], october, tenth);
      expect(BudgetText.alertTitle(status.budget, october, 1, settings), '80% of your October budget used');
      expect(BudgetText.alertBody(status), '₹20,000 of ₹25,000 · 21 days left');
      expect(BudgetText.alertTitle(_budget(6000, category: 'Food'), october, 3, settings), 'Food is over budget');
    });
  });

  group('BudgetCheck (database)', () {
    late DatabaseHelper db;
    late _FakeNotifier notifier;
    late BudgetCheck check;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      DatabaseHelper.fileName = 'budget_test.db';
      await databaseFactory.deleteDatabase(p.join(await getDatabasesPath(), DatabaseHelper.fileName));
      db = DatabaseHelper();
    });

    setUp(() async {
      final database = await db.database;
      for (final table in ['expenses', 'budgets', 'settings']) {
        await database.delete(table);
      }
      notifier = _FakeNotifier();
      check = BudgetCheck(db: db, notifier: notifier);
    });

    Future<void> spend(double amount, [String category = 'Food']) =>
        db.insertExpense(Expense(amount: amount, category: category, date: tenth));

    test('each level alerts once a month', () async {
      await db.setBudget(Budget.overall, 25000, tenth);
      await spend(20000);
      await check.check(tenth);
      await check.check(tenth);
      expect(notifier.shown, ['80% of your October budget used']);
      await spend(2500);
      await check.check(tenth);
      expect(notifier.shown.last, '90% of your October budget used');
      expect(notifier.shown, hasLength(2));
    });

    test('one big payment across several levels sends one alert', () async {
      await db.setBudget(Budget.overall, 25000, tenth);
      await spend(26000);
      await check.check(tenth);
      expect(notifier.shown, ["You're over your October budget"]);
    });

    test('raising the budget lets a level alert again when crossed again', () async {
      await db.setBudget(Budget.overall, 25000, tenth);
      await spend(20000);
      await check.check(tenth);
      await db.setBudget(Budget.overall, 30000, tenth);
      await check.check(tenth); // 67%: back below the first warning
      await spend(4000); // 80% of ₹30,000
      await check.check(tenth);
      expect(notifier.shown, ['80% of your October budget used', '80% of your October budget used']);
    });

    test('category budgets alert on their own; split parts count', () async {
      await db.setBudget('Food', 1000, tenth);
      final payment = Expense(amount: 3000, category: 'Food', date: tenth);
      await db.saveSplit(payment, [SplitPart('Food', 1100), SplitPart('Shopping', 1900)]);
      await check.check(tenth);
      expect(notifier.shown, ['Food is over budget']);
    });

    test('alerts off: nothing shown', () async {
      await db.setSetting(BudgetAlertSettings.enabledKey, 'false');
      await db.setBudget(Budget.overall, 1000, tenth);
      await spend(5000);
      await check.check(tenth);
      expect(notifier.shown, isEmpty);
    });

    test('a renamed category keeps its budget; a deleted one loses it', () async {
      await db.setBudget('Snacks', 500, tenth);
      final id = await db.insertCategory(ExpenseCategory(name: 'Snacks', emoji: 'icon:cookie', colorValue: 0xFF000000));
      final snacks = ExpenseCategory(id: id, name: 'Munchies', emoji: 'icon:cookie', colorValue: 0xFF000000);
      await db.updateCategory(snacks, 'Snacks');
      expect(budgetsIn(await db.getBudgets(), october).single.category, 'Munchies');
      await db.deleteCategoryMovingTo(snacks, 'Food');
      expect(await db.getBudgets(), isEmpty);
    });
  });
}
