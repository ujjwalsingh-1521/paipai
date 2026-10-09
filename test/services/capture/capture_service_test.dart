import 'package:expense_tracker/db/database_helper.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/pending_transaction.dart';
import 'package:expense_tracker/models/split_part.dart';
import 'package:expense_tracker/services/capture/capture_alerts.dart';
import 'package:expense_tracker/services/capture/capture_service.dart';
import 'package:expense_tracker/services/capture/parsed_payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Records what would have been shown as Android notifications.
class _FakeAlerts implements CaptureAlerts {
  final shown = <({PendingTransaction tx, Suggestions suggestions})>[];

  @override
  Future<void> showReview(PendingTransaction tx, Suggestions suggestions,
      {bool update = false}) async {
    shown.add((tx: tx, suggestions: suggestions));
  }

  @override
  Future<void> cancel(int pendingId) async {}

  @override
  Future<void> dataChanged() async {}
}

var _ref = 412345678900;
var _time = DateTime(2026, 10, 1, 9);

/// A bank SMS for a new payment (fresh reference, an hour after the last).
NotificationInput _sms(String payee, {int amount = 250}) {
  _ref++;
  _time = _time.add(const Duration(hours: 1));
  return NotificationInput(
    app: 'com.google.android.apps.messaging',
    title: 'AX-HDFCBK',
    text: 'Rs.$amount.00 debited from A/c XX1234 to $payee. UPI Ref $_ref',
    postedAt: _time,
    messageId: '$_ref',
  );
}

void main() {
  group('Suggestions.rank', () {
    const all = ['Food', 'Transport', 'Shopping', 'Bills', 'Health', 'Other'];

    test('most-picked for this payee first, then recent favourites, then the rest', () {
      final s = Suggestions.rank(
        payeeHistory: ['Food', 'Shopping', 'Shopping', 'Health', 'Shopping', 'Food'],
        recentTop: ['Bills', 'Food'],
        all: all,
      );
      expect(s.ordered, ['Shopping', 'Food', 'Health', 'Bills', 'Transport', 'Other']);
      expect(s.usual, 'Shopping');
      expect(s.forNotification, ['Shopping', 'Food']);
    });

    test('a tie goes to the most recent choice', () {
      final s = Suggestions.rank(payeeHistory: ['Health', 'Food'], recentTop: [], all: all);
      expect(s.forNotification, ['Health', 'Food']);
    });

    test('a new payee gets the recent favourites and no pre-selection', () {
      final s = Suggestions.rank(payeeHistory: [], recentTop: ['Bills'], all: all);
      expect(s.forNotification, ['Bills', 'Food']);
      expect(s.usual, isNull);
    });

    test('Other goes last unless it is the usual choice', () {
      final rarely = Suggestions.rank(payeeHistory: [], recentTop: ['Other', 'Bills'], all: all);
      expect(rarely.forNotification, ['Bills', 'Food']);
      expect(rarely.ordered.last, 'Other');
      final usually = Suggestions.rank(payeeHistory: ['Other'], recentTop: [], all: all);
      expect(usually.forNotification, ['Other', 'Food']);
    });

    test('deleted categories are never suggested', () {
      final s = Suggestions.rank(payeeHistory: ['Games', 'Games'], recentTop: ['Games'], all: all);
      expect(s.ordered, all);
      expect(s.usual, isNull);
    });
  });

  group('CaptureService', () {
    late _FakeAlerts alerts;
    late CaptureService service;
    final db = DatabaseHelper();

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      DatabaseHelper.fileName = 'capture_service_test.db';
      await databaseFactory.deleteDatabase(p.join(await getDatabasesPath(), DatabaseHelper.fileName));
    });

    setUp(() {
      alerts = _FakeAlerts();
      service = CaptureService(alerts: alerts, db: db);
    });

    Future<PendingTransaction> capture(String payee) async {
      await service.handleNotification(_sms(payee));
      return alerts.shown.last.tx;
    }

    test('never files a payment by itself, however often a shop was labelled', () async {
      for (var i = 0; i < 5; i++) {
        await service.categorize((await capture('BLINKIT')).id!, 'Shopping');
      }
      final next = await capture('BLINKIT');
      final saved = await db.getPendingTransaction(next.id!);
      expect(saved!.isProcessed, isFalse);
      expect(alerts.shown.last.suggestions.usual, 'Shopping');
    });

    test("the alert offers the shop's usual categories in order", () async {
      await service.categorize((await capture('BLINKIT')).id!, 'Food');
      await service.categorize((await capture('BLINKIT')).id!, 'Food');
      await capture('BLINKIT');
      // Blinkit so far: Shopping x5, Food x2.
      expect(alerts.shown.last.suggestions.forNotification, ['Shopping', 'Food']);
    });

    test('editing an entry in History changes the next suggestion', () async {
      final tx = await capture('METRO CARD');
      await service.categorize(tx.id!, 'Shopping');
      final processed = await db.getPendingTransaction(tx.id!);
      final expense = (await db.getAllExpenses())
          .firstWhere((e) => e.id == processed!.createdExpenseId);
      await db.updateExpense(Expense(
          id: expense.id, amount: expense.amount, category: 'Transport', date: expense.date));

      await capture('METRO CARD');
      expect(alerts.shown.last.suggestions.usual, 'Transport');
    });

    test('a labelled payment keeps its payee apart from the note', () async {
      final tx = await capture('ZEPTO');
      await service.categorize(tx.id!, 'Food');
      final saved = await db.getPendingTransaction(tx.id!);
      final expense = (await db.getAllExpenses()).firstWhere((e) => e.id == saved!.createdExpenseId);
      expect(expense.payee, tx.merchant);
      expect(expense.notes, isNull);
    });

    test('a captured payment can be split; every part counts for suggestions', () async {
      final tx = await capture('DMART');
      await service.categorizeSplit(tx.id!, const [
        SplitPart('Groceries', 150), // the test payment is ₹250
        SplitPart('Food', 60),
        SplitPart('Shopping', 40),
      ]);
      final saved = await db.getPendingTransaction(tx.id!);
      expect(saved!.isProcessed, isTrue);
      final parts = await db.getSplitParts(saved.createdExpenseId!);
      expect(parts.map((p) => p.category), ['Groceries', 'Food', 'Shopping']);
      expect(parts.every((p) => p.payee == tx.merchant), isTrue);

      await capture('DMART');
      expect(alerts.shown.last.suggestions.ordered.take(3), containsAll(['Groceries', 'Food', 'Shopping']));
    });

    test('a split can be changed, undone back to one payment, and deleted', () async {
      final payment = Expense(amount: 1000, category: 'Food', date: DateTime(2026, 10, 5), payee: 'Cafe');
      final id = await db.saveSplit(payment, const [SplitPart('Food', 700), SplitPart('Shopping', 300)]);
      final lead = (await db.getSplitParts(id)).first;

      await db.saveSplit(lead, const [SplitPart('Food', 500), SplitPart('Health', 300), SplitPart('Bills', 200)]);
      final changed = await db.getSplitParts(id);
      expect(changed.map((p) => p.amount), [500, 300, 200]);
      expect(changed.first.id, id);

      await db.unsplit(id);
      final single = (await db.getAllExpenses()).firstWhere((e) => e.id == id);
      expect(single.amount, 1000);
      expect(single.splitId, isNull);
      expect(await db.getSplitParts(id), isEmpty);

      final again = await db.saveSplit(single, const [SplitPart('Food', 600), SplitPart('Bills', 400)]);
      final removed = await db.deleteSplit(again);
      expect(removed.length, 2);
      expect((await db.getAllExpenses()).where((e) => e.splitId == again), isEmpty);
    });
  });
}
