import 'package:expense_tracker/services/capture/sms_sender.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bank headers are read, whatever their suffix', () {
    for (final sender in ['AX-HDFCBK-S', 'JM-KOTAKB-T', 'VD-SBIUPI-G', 'AD-KOTAKB', 'HDFC Bank', '56767']) {
      expect(SmsSender.isIgnored(sender), isFalse, reason: sender);
    }
  });

  test('promotional headers and phone numbers are ignored', () {
    for (final sender in ['AX-MEESHO-P', 'vm-offers-p', '+919812345678', '9812345678', '+91 98123 45678']) {
      expect(SmsSender.isIgnored(sender), isTrue, reason: sender);
    }
  });
}
