import 'package:expense_tracker/models/pending_transaction.dart';
import 'package:expense_tracker/services/capture/app_kinds.dart';
import 'package:expense_tracker/services/capture/parsed_payment.dart';
import 'package:expense_tracker/services/capture/payment_matcher.dart';
import 'package:expense_tracker/services/capture/payment_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'payment_samples.dart';

const _sms = 'com.google.android.apps.messaging';
const _gpay = 'com.google.android.apps.nbu.paisa.user';
const _gmail = 'com.google.android.gm';
final _start = DateTime(2026, 10, 3, 12);

ParsedPayment _parse(String app, String title, String text, DateTime at) =>
    PaymentParser.parse(NotificationInput(app: app, title: title, text: text, postedAt: at))!;

PendingTransaction _record(ParsedPayment p, int id) => PendingTransaction(
      id: id,
      amount: p.amount,
      type: p.direction.name,
      merchant: p.payee,
      upiRef: p.reference,
      accountTail: p.accountTail,
      rawMessage: p.source.text,
      sender: p.source.title,
      confidence: 100,
      detectedAt: p.source.postedAt,
      sourceApp: p.source.app,
    );

/// Feeds alerts through the matcher the way CaptureService does and
/// returns the resulting records.
List<PendingTransaction> _capture(List<ParsedPayment> alerts) {
  final records = <PendingTransaction>[];
  for (final alert in alerts) {
    final match = PaymentMatcher.findSamePayment(alert, records);
    if (match == null) {
      records.add(_record(alert, records.length + 1));
    } else {
      records[records.indexOf(match)] = PaymentMatcher.merge(match, alert);
    }
  }
  return records;
}

ParsedPayment _sample(String id, DateTime at) {
  final s = paymentSamples.firstWhere((s) => s.id == id);
  return _parse(s.app, s.title, s.text, at);
}

void main() {
  group('one payment reported by several apps becomes one record', () {
    for (final ids in samePaymentGroups) {
      test(ids.join(' + '), () {
        final alerts = [
          for (var i = 0; i < ids.length; i++)
            _sample(ids[i], _start.add(Duration(minutes: i * 2))),
        ];
        final records = _capture(alerts);
        expect(records, hasLength(1));
        expect(records.single.seenCount, ids.length);
      });
    }

    test('all groups together still give one record per payment', () {
      final alerts = <ParsedPayment>[];
      for (var g = 0; g < samePaymentGroups.length; g++) {
        final groupStart = _start.add(Duration(hours: g));
        for (var i = 0; i < samePaymentGroups[g].length; i++) {
          alerts.add(_sample(samePaymentGroups[g][i], groupStart.add(Duration(minutes: i))));
        }
      }
      expect(_capture(alerts), hasLength(samePaymentGroups.length));
    });

    test('keeps the readable payee name over a UPI id', () {
      final records = _capture([
        _parse(_sms, 'AX-HDFCBK', 'Rs.250.00 debited from A/c XX1234 to sharma@okaxis. UPI Ref 412345678901', _start),
        _parse(_gpay, 'Sharma General Store', 'You paid ₹250 · UPI ID 412345678901', _start.add(const Duration(minutes: 1))),
      ]);
      expect(records.single.merchant, 'Sharma General Store');
    });

    // The user's phone, 2026-10-14: the Kotak 811 app alert came 14 min after the SMS.
    test('a late bank-app alert without a reference merges by the payer name', () {
      final records = _capture([
        _sample('kotak_sms_received_person', _start),
        _sample('sbi_upi_credited_transfer_from', _start),
        _sample('gpay_paid_you_via_other_app', _start.add(const Duration(minutes: 1))),
        _sample('kotak811_app_received_person', _start.add(const Duration(minutes: 14))),
      ]);
      expect(records, hasLength(1));
      expect(records.single.seenCount, 4);
      expect(records.single.maybeMultiple, isFalse);
    });

    // The user's phone, 2026-10-17: 14 min late, and the app's payee has an extra word.
    test('a late bank-app alert merges on the same account even when the names differ', () {
      final records = _capture([
        _sample('kotak_sms_sent_shop_short_name', _start),
        _sample('kotak811_app_paid_shop_long_name', _start.add(const Duration(minutes: 14))),
      ]);
      expect(records, hasLength(1));
      expect(records.single.merchant, 'Ganesh Vegitable shop');
    });

    // The user's phone, 2026-10-13: the app alert for a ₹150 credit came 40 min later.
    test('a bank-app alert up to 90 min late still merges', () {
      final records = _capture([
        _sample('kotak_sms_received_person', _start),
        _sample('kotak811_app_received_person', _start.add(const Duration(minutes: 40))),
      ]);
      expect(records, hasLength(1));
    });

    test('a late alert joins the closest payment of the same amount', () {
      final records = _capture([
        _parse(_sms, 'JM-KOTAKB-S', 'Sent Rs.220.00 from Kotak Bank A/c X5678 to A. UPI Ref 629067600011', _start),
        _parse(_sms, 'JM-KOTAKB-S', 'Sent Rs.220.00 from Kotak Bank A/c X5678 to B. UPI Ref 629067600012',
            _start.add(const Duration(minutes: 30))),
        _sample('kotak811_app_paid_shop_long_name', _start.add(const Duration(minutes: 35))),
      ]);
      expect(records.map((r) => r.seenCount), [1, 2]);
    });

    test('a late email with the same reference still merges', () {
      final records = _capture([
        _parse(_sms, 'AX-HDFCBK', 'Rs.450.00 debited from A/c XX1234. UPI Ref 412345678901', _start),
        _parse(_gmail, 'HDFC Bank InstaAlerts', 'Rs.450.00 has been debited from account **1234. UPI ref 412345678901',
            _start.add(const Duration(hours: 5))),
      ]);
      expect(records, hasLength(1));
    });
  });

  group('different payments stay separate', () {
    test('same amount, different reference numbers', () {
      final records = _capture([
        _parse(_sms, 'AX-HDFCBK', 'Rs.20.00 debited from A/c XX1234 to CHAI POINT. UPI Ref 412345678901', _start),
        _parse(_sms, 'AX-HDFCBK', 'Rs.20.00 debited from A/c XX1234 to CHAI POINT. UPI Ref 412345678902',
            _start.add(const Duration(minutes: 3))),
      ]);
      expect(records, hasLength(2));
    });

    test('money out and money in of the same amount (own transfer)', () {
      final records = _capture([
        _parse(_sms, 'AX-HDFCBK', 'Rs.5000.00 debited from A/c XX1234 to self', _start),
        _parse(_sms, 'JD-ICICIT', 'ICICI Bank Account XX987 credited:Rs. 5,000.00. Info NEFT-SELF',
            _start.add(const Duration(minutes: 1))),
      ]);
      expect(records, hasLength(2));
    });

    test('same amount from two different accounts', () {
      final records = _capture([
        _parse(_sms, 'AX-HDFCBK', 'Rs.300.00 debited from A/c XX1234 at DMART', _start),
        _parse(_sms, 'JD-ICICIT', 'Rs.300.00 debited from A/c XX9876 at DMART', _start.add(const Duration(minutes: 1))),
      ]);
      expect(records, hasLength(2));
    });

    test('a bank-app alert two hours after the SMS is a new payment', () {
      final records = _capture([
        _sample('kotak_sms_received_person', _start),
        _sample('kotak811_app_received_person', _start.add(const Duration(hours: 2))),
      ]);
      expect(records, hasLength(2));
    });

    test('a late bank-app alert naming someone else is a new payment', () {
      final records = _capture([
        _parse(_sms, 'JM-KOTAKB-S', 'Sent Rs.220.00 from Kotak Bank A/c X5678 to Ravi Kumar. UPI Ref 629067600031', _start),
        _sample('kotak811_app_paid_shop_long_name', _start.add(const Duration(minutes: 30))),
      ]);
      expect(records, hasLength(2));
    });

    test('a second alert from an app the payment already has is another payment', () {
      final records = _capture([
        _sample('kotak_sms_sent_shop_short_name', _start),
        _sample('kotak811_app_paid_shop_long_name', _start.add(const Duration(minutes: 14))),
        // Half an hour later the bank app alone reports ₹220 more (UPI Lite, no SMS).
        _sample('kotak811_app_paid_shop_long_name', _start.add(const Duration(minutes: 45))),
      ]);
      expect(records, hasLength(2));
    });

    test('bank SMS read by PaiPai itself merge with a late bank-app alert too', () {
      final records = _capture([
        _parse(AppKinds.smsSource, 'JM-KOTAKB-S',
            'Sent Rs.220.00 from Kotak Bank A/c X5678 to Ganesh Vegitable  on 17-10-26. UPI Ref 629067600041', _start),
        _sample('kotak811_app_paid_shop_long_name', _start.add(const Duration(minutes: 14))),
      ]);
      expect(records, hasLength(1));
    });

    test('a late alert from a different account is a new payment', () {
      final records = _capture([
        _parse(_sms, 'JM-KOTAKB-S', 'Sent Rs.220.00 from Kotak Bank A/c X9999 to Ganesh Vegitable. UPI Ref 629067600021', _start),
        _sample('kotak811_app_paid_shop_long_name', _start.add(const Duration(minutes: 14))),
      ]);
      expect(records, hasLength(2));
    });

    test('same payee in the same app, without references, far apart in time', () {
      final records = _capture([
        _parse(_sms, 'AX-HDFCBK', 'Rs.20.00 debited from A/c XX1234 to CHAI POINT', _start),
        _parse(_sms, 'AX-HDFCBK', 'Rs.20.00 debited from A/c XX1234 to CHAI POINT', _start.add(const Duration(minutes: 40))),
      ]);
      expect(records, hasLength(2));
    });

    test('same amount, different payees, without references, 30 min apart', () {
      final records = _capture([
        _parse(_sms, 'AX-HDFCBK', 'Rs.250.00 debited from A/c XX1234 to CHAI POINT', _start),
        _parse(_gpay, 'Sharma Store', 'You paid ₹250', _start.add(const Duration(minutes: 30))),
      ]);
      expect(records, hasLength(2));
    });

    test('same amount without references, far apart in time', () {
      final records = _capture([
        _parse(_sms, 'AX-HDFCBK', 'Rs.100.00 debited from A/c XX1234 at CAFE', _start),
        _parse(_sms, 'AX-HDFCBK', 'Rs.100.00 debited from A/c XX1234 at CAFE', _start.add(const Duration(minutes: 40))),
      ]);
      expect(records, hasLength(2));
    });
  });

  group('uncertain merges are flagged for the user', () {
    test('same app, same amount, no reference: merged but marked "maybe 2"', () {
      final records = _capture([
        _parse(_sms, 'AX-HDFCBK', 'Rs.20.00 debited from A/c XX1234 at CHAI POINT', _start),
        _parse(_sms, 'AX-HDFCBK', 'Rs.20.00 debited from A/c XX1234 at CHAI POINT', _start.add(const Duration(minutes: 3))),
      ]);
      expect(records, hasLength(1));
      expect(records.single.maybeMultiple, isTrue);
    });

    test('different apps reporting one payment are not flagged', () {
      final records = _capture([
        _parse(_sms, 'AX-HDFCBK', 'Rs.250.00 debited from A/c XX1234', _start),
        _parse(_gpay, 'Sharma Store', 'You paid ₹250', _start.add(const Duration(minutes: 1))),
      ]);
      expect(records.single.maybeMultiple, isFalse);
    });
  });
}
