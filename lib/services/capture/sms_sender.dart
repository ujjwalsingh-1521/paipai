/// Who sent an SMS, from its sender address. Indian businesses send from
/// registered headers ("AX-HDFCBK-S"); since 2023 the last part says what
/// kind of message it is: S = service, T = transactional, G = government,
/// P = promotional. Bank alerts never come as promotions or from a
/// person's number (those are ads or forwarded messages).
class SmsSender {
  static final _header = RegExp(r'^[A-Z]{2}-[A-Z0-9]{3,9}(?:-([A-Z]))?$');
  static final _phoneNumber = RegExp(r'^\+?\d{10,13}$');

  /// True for promotional headers and personal phone numbers.
  static bool isIgnored(String address) {
    final sender = address.trim().toUpperCase().replaceAll(' ', '');
    if (_phoneNumber.hasMatch(sender)) return true;
    return _header.firstMatch(sender)?.group(1) == 'P';
  }
}
