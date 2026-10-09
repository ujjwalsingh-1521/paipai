import 'package:expense_tracker/models/pending_transaction.dart';
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
