import 'package:expense_tracker/services/capture/parsed_payment.dart';
import 'package:expense_tracker/services/capture/payment_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'payment_samples.dart';

ParsedPayment? parseSample(PaymentSample sample, {DateTime? at}) =>
    PaymentParser.parse(NotificationInput(
      app: sample.app,
      title: sample.title,
      text: sample.text,
      postedAt: at ?? DateTime(2026, 10, 3, 12),
      messageId: sample.id,
    ));

void main() {
  group('real-world payment messages', () {
    for (final sample in paymentSamples.where((s) => s.expect != null)) {
      test(sample.id, () {
        final expected = sample.expect!;
        final parsed = parseSample(sample);
        expect(parsed, isNotNull, reason: 'not recognised: ${sample.text}');
        expect(parsed!.amount, expected.amount, reason: sample.text);
        expect(parsed.direction.name, expected.direction, reason: sample.text);
        if (expected.payee != null) {
          expect(parsed.payee?.toLowerCase(), contains(expected.payee!.toLowerCase()),
              reason: sample.text);
        }
        if (expected.reference != null) {
          expect(parsed.reference, expected.reference, reason: sample.text);
        }
        if (expected.accountTail != null) {
          expect(parsed.accountTail, expected.accountTail, reason: sample.text);
        }
      });
    }
  });

  group('messages that are not payments', () {
    for (final sample in paymentSamples.where((s) => s.expect == null)) {
      test(sample.id, () {
        expect(parseSample(sample), isNull, reason: sample.text);
      });
    }
  });

  group('payee cleanup', () {
    test('turns SHOUTING names into Title Case but keeps UPI ids', () {
      expect(PaymentParser.cleanPayee('SHARMA GENERAL STORE'), 'Sharma General Store');
      expect(PaymentParser.cleanPayee('sharma@okaxis'), 'sharma@okaxis');
    });

    test('rejects things that are not names', () {
      expect(PaymentParser.cleanPayee('your a/c'), isNull);
      expect(PaymentParser.cleanPayee('12345678'), isNull);
      expect(PaymentParser.cleanPayee('Rs 500'), isNull);
    });

    test("rejects the user's own card, but keeps shops with 'card' in the name", () {
      expect(PaymentParser.cleanPayee('AU Bank Credit Card x1234'), isNull);
      expect(PaymentParser.cleanPayee('Card XX5678'), isNull);
      expect(PaymentParser.cleanPayee('METRO CARD'), 'Metro Card');
    });
  });

  group('our own alerts', () {
    test('are never read back in', () {
      final own = PaymentParser.parse(NotificationInput(
        app: 'com.expense.expense_tracker',
        title: '₹250 paid · Store',
        text: 'Rs 250 debited from A/c XX1234',
        postedAt: DateTime(2026, 10, 3),
      ));
      expect(own, isNull);
    });
  });
}
