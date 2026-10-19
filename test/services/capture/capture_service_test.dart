import 'package:expense_tracker/db/database_helper.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/pending_transaction.dart';
import 'package:expense_tracker/models/split_part.dart';
import 'package:expense_tracker/services/capture/app_kinds.dart';
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

    test('a note typed before saving goes into notes, the payee stays the payee', () async {
      final tx = await capture('CHAI POINT');
      await service.categorize(tx.id!, 'Food', note: '  tea with Ravi ');
      final saved = await db.getPendingTransaction(tx.id!);
      final expense = (await db.getAllExpenses()).firstWhere((e) => e.id == saved!.createdExpenseId);
      expect(expense.notes, 'tea with Ravi');
      expect(expense.payee, tx.merchant);
    });

    group('bank SMS read by PaiPai itself', () {
      NotificationInput sms(String text, DateTime at, {String id = ''}) => NotificationInput(
          app: AppKinds.smsSource, title: 'JM-KOTAKB-S', text: text, postedAt: at, messageId: id);

      test("the messages app's notification of the same SMS is ignored", () async {
        final shown = alerts.shown.length;
        await service.handleNotification(NotificationInput(
          app: 'com.google.android.apps.messaging',
          title: 'JM-KOTAKB-S',
          text: 'Sent Rs.75.00 from Kotak Bank A/c X5678 to TEA STALL. UPI Ref 629300000001',
          postedAt: DateTime.now(),
          smsCaptureActive: true,
        ));
        expect(alerts.shown.length, shown);
      });

      test('an SMS seen live and again by a scan or an import is one payment', () async {
        final at = DateTime.now().subtract(const Duration(minutes: 5));
        const text = 'Sent Rs.88.00 from Kotak Bank A/c X5678 to BAKERY. UPI Ref 629300000002';
        await service.handleNotification(sms(text, at, id: 'sms:a:1'));
        final id = alerts.shown.last.tx.id!;
        // Same id: the scan. A different id: the fingerprint was pruned long ago.
        await service.handleNotification(sms(text, at, id: 'sms:a:1'), mode: CaptureMode.catchUp);
        await service.handleNotification(sms(text, at, id: 'other'), mode: CaptureMode.import);
        final saved = await db.getPendingTransaction(id);
        expect(saved!.seenCount, 1);
        final copies = (await db.getAllPendingTransactions()).where((t) => t.upiRef == '629300000002');
        expect(copies, hasLength(1));
      });

      test('two identical SMS for two real payments both count', () async {
        // No reference, no time in the text: byte-identical for two ₹20 chais.
        const text = 'Rs.20.00 debited from A/c XX5678 to TEA STALL on 18-10-26';
        final first = DateTime.now().subtract(const Duration(hours: 3));
        await service.handleNotification(sms(text, first, id: 'sms:t:1'));
        await service.handleNotification(sms(text, first.add(const Duration(minutes: 20)), id: 'sms:t:2'));
        // A scan finding both again adds nothing.
        await service.handleNotification(sms(text, first, id: 'sms:t:1'), mode: CaptureMode.catchUp);
        final chais = (await db.getAllPendingTransactions()).where((t) => t.merchant == 'Tea Stall');
        expect(chais, hasLength(2));
      });

      test('imported and old caught-up SMS wait quietly; recent ones still alert', () async {
        final shown = alerts.shown.length;
        final old = DateTime.now().subtract(const Duration(days: 20));
        await service.handleNotification(
            sms('Sent Rs.91.00 from Kotak Bank A/c X5678 to A. UPI Ref 629300000003', old),
            mode: CaptureMode.import);
        await service.handleNotification(
            sms('Sent Rs.92.00 from Kotak Bank A/c X5678 to B. UPI Ref 629300000004', old),
            mode: CaptureMode.catchUp);
        expect(alerts.shown.length, shown);
        await service.handleNotification(
            sms('Sent Rs.93.00 from Kotak Bank A/c X5678 to C. UPI Ref 629300000005',
                DateTime.now().subtract(const Duration(minutes: 30))),
            mode: CaptureMode.catchUp);
        expect(alerts.shown.length, shown + 1);
        final waiting = await db.getAllPendingTransactions(unprocessedOnly: true);
        expect(waiting.map((t) => t.upiRef), containsAll(['629300000003', '629300000004']));
      });
    });

    test('two taps racing on one payment save it once', () async {
      final tx = await capture('SWIGGY');
      final before = (await db.getAllExpenses()).length;
      // Two engines (the alert button and the More card) at the same moment.
      final other = CaptureService(alerts: _FakeAlerts(), db: DatabaseHelper());
      await Future.wait([service.categorize(tx.id!, 'Food'), other.categorize(tx.id!, 'Shopping')]);
      expect((await db.getAllExpenses()).length, before + 1);
      // A split arriving after the save does nothing either.
      await service.categorizeSplit(tx.id!, const [SplitPart('Food', 200), SplitPart('Shopping', 50)]);
      expect((await db.getAllExpenses()).length, before + 1);
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
