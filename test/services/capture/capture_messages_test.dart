import 'package:expense_tracker/models/pending_transaction.dart';
import 'package:expense_tracker/services/capture/parsed_payment.dart';
import 'package:expense_tracker/services/capture/payment_matcher.dart';
import 'package:expense_tracker/services/capture/payment_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sms = NotificationInput(
    app: 'com.google.android.apps.messaging',
    title: 'AX-HDFCBK',
    text: 'Rs.250.00 debited from A/c XX1234 to riya.s@okaxis. UPI Ref 512345678901',
    postedAt: DateTime(2026, 10, 4, 18, 32),
  );

  test('a merged alert keeps both messages, each with where it came from', () {
    const first = 'You paid ₹250 to Riya';
    final stored = CaptureMessages.append(first, sms);
    final parts = CaptureMessages.split(stored);
    expect(parts.length, 2);
    expect(parts[0].heading, isNull);
    expect(parts[0].text, first);
    expect(parts[1].heading, 'Messages (SMS) · AX-HDFCBK · 18:32');
    expect(parts[1].text, sms.text);
  });

  test('UPI ids are found, email addresses are not', () {
    const text = 'Paid to riya.s@okaxis. Receipt sent to me@gmail.com. Also 98765@ybl';
    expect(CaptureMessages.upiIds(text), ['riya.s@okaxis', '98765@ybl']);
  });

  test('merging two alerts of one payment stores the second message too', () {
    final existing = PendingTransaction(
      id: 1,
      amount: 250,
      type: 'debit',
      merchant: 'Riya',
      rawMessage: 'You paid ₹250 to Riya',
      sender: 'Google Pay',
      confidence: 100,
      detectedAt: DateTime(2026, 10, 4, 18, 30),
      sourceApp: 'com.google.android.apps.nbu.paisa.user',
    );
    final merged = PaymentMatcher.merge(existing, PaymentParser.parse(sms)!);
    expect(merged.seenCount, 2);
    expect(CaptureMessages.split(merged.rawMessage).map((m) => m.text), [existing.rawMessage, sms.text]);
  });
}
