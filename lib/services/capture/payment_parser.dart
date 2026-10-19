import 'app_kinds.dart';
import 'parsed_payment.dart';
import 'sms_sender.dart';

/// Recognises payments in notifications from any bank, card, UPI app or
/// email alert. It relies on the wording all Indian payment alerts share
/// (amount, debited/credited, a/c tail, reference) instead of per-bank
/// templates, so new banks work without changes.
class PaymentParser {
  static ParsedPayment? parse(NotificationInput input) {
    if (AppKinds.isIgnored(input.app)) return null;
    // An SMS's title is its sender: ads and forwards aren't bank alerts.
    if (AppKinds.of(input.app) == AppKind.sms && SmsSender.isIgnored(input.title)) return null;
    final text = _combine(input);
    final lower = text.toLowerCase();
    if (_notATransaction.any((pattern) => pattern.hasMatch(lower))) return null;

    final direction = detectDirection(lower);
    final receiptTotal = AppKinds.of(input.app) == AppKind.email ? extractReceiptTotal(lower) : null;
    final amount = receiptTotal ?? extractAmount(lower);
    if (direction == null || amount == null) return null;

    final tail = extractAccountTail(lower);
    final reference = extractReference(lower);
    if (!_hasFinancialEvidence(input, lower, tail, reference)) return null;

    return ParsedPayment(
      amount: amount,
      direction: direction,
      // A receipt's sender is the shop; its text names the restaurant, the
      // address and fine print ("issue an invoice directly to you").
      payee: (receiptTotal != null ? _senderName(input) : null) ??
          extractPayee(text, direction) ??
          _payeeFromTitle(input),
      reference: reference,
      accountTail: tail,
      source: input,
    );
  }

  // Line breaks are kept: multi-line card alerts put the payee on its own line.
  static String _combine(NotificationInput input) => '${input.title}. ${input.text}'
      .replaceAll(RegExp(r'[ \t ]+'), ' ')
      .replaceAll(RegExp(r' ?\n ?'), '\n')
      .trim();

  // --- 1. Messages that mention money but are not a completed payment ---

  static final _notATransaction = [
    RegExp(r'\botp\b\s*(?:is|:|for|to|of)\b'),
    RegExp(r'\bis\s+(?:your|the)\s+(?:otp|one[\s-]?time)'),
    RegExp(r'one[\s-]?time\s+pass(?:word|code)'),
    RegExp(r'verification\s+code'),
    RegExp(r'\b(?:failed|declined|unsuccessful|rejected)\b'),
    RegExp(r'\b(?:was|is|has)\s+not\s+(?:been\s+)?(?:successful|processed|completed)'),
    RegExp(r'could\s+not\s+be\s+(?:processed|completed)'),
    RegExp(r'insufficient\s+(?:funds|balance)'),
    RegExp(r'\b(?:has|have)\s+requested\b|\bis\s+requesting\b|'
        r'\b(?:payment|collect|money)\s+request\b|\brequested\s+(?:you|money|for|₹|rs|inr)'),
    RegExp(r'\b(?:mandate|autopay|auto[\s-]pay|standing\s+instruction|e-?nach)\b[^.]{0,60}?'
        r'\b(?:created|registered|set\s?up|activated|approved|modified|revoked|cancell?ed|paused)\b'),
    RegExp(r'\bmandate\b[\s\S]{0,140}?\b(?:received|for\s+processing)\b'),
    RegExp(r'\b(?:will|to|shall)\s+be\s+(?:auto[\s-]?)?(?:debited|deducted|charged)\b'),
    RegExp(r'\bdue\s+(?:on|date|by)\b|\bis\s+due\b|\bpayment\s+due\b|'
        r'\b(?:minimum|min\.?|total)\s+(?:amount\s+)?due\b|\boverdue\b'),
    RegExp(r'\bstatement\s+(?:is\s+|has\s+been\s+)?generated\b|\be-?statement\b|'
        r'\bbill\s+(?:is\s+|has\s+been\s+)?generated\b'),
    RegExp(r'\breminder\b|\bupcoming\b'),
    RegExp(r'\b(?:up\s?to|upto)\s*(?:₹|rs\.?|inr)?\s*[0-9,]+\s*(?:cashback|off|discount)|'
        r'\b(?:cashback|discount|off)\s+(?:of\s+)?up\s?to\b'),
    RegExp(r'\bpre-?approved\b|\bloan\s+(?:offer|approved|of\s+up\s?to)\b|\bapply\s+now\b|'
        r'\buse\s+code\b|\bt&c\b|\blimited\s+period\b|\bclaim\s+(?:now|your)\b'),
    // "Get a personal loan of Rs. 5,500 ... sent directly to your bank account"
    RegExp(r'\b(?:get|avail|take)\s+(?:an?\s+)?(?:instant\s+|personal\s+|quick\s+)*loan\b|'
        r'\bloan\s+of\s+(?:up\s?to\s+)?(?:₹|rs\.?|inr)|\bcheck\s+(?:your|the)\s+offer\b'),
    RegExp(r'\bkyc\b'),
    // A card company acknowledging a bill payment: the bank's debit
    // alert already recorded that money leaving.
    RegExp(r'received\s+(?:towards|against|for)\s+(?:your\s+)?(?:[a-z]+\s+)?(?:credit\s+)?card'),
    RegExp(r'thank\s+you\s+for\s+(?:your\s+|the\s+)?payment[^.]{0,40}(?:card|towards|bill)'),
  ];

  // --- 2. Direction: strong words win over weak ones; earliest wins ---

  // "Dr"/"Cr" count only beside an amount ("Rs 500 Dr", "Cr. INR 500"),
  // so "from Dr. Sharma" is not read as a debit.
  // The match includes the currency, so a balance label right before it
  // ("Total Bal:Rs.15000.00CR") is recognised and skipped.
  static const _amountThen = r'(?:₹|rs\.?|inr)\s*:?\s*[0-9][0-9,]*(?:\.[0-9]{1,2})?\s*';
  static final _strongDebit = RegExp(
      r'\b(?:debited|debit(?:ed)?\s+(?:of|for|by|with)|deducted|withdrawn|withdrawal|spent|charged)\b|'
      '${_amountThen}dr\\b|\\bdr\\.?\\s*(?:₹|rs|inr|with|by|for)\\b');
  static final _strongCredit = RegExp(
      r'\b(?:credited|deposited|refund(?:ed)?|reversed|reversal|(?:has|have)\s+(?:a\s+)?credit)\b|'
      '${_amountThen}cr\\b|\\bcr\\.?\\s*(?:₹|rs|inr|with|by|for)\\b');
  static final _weakDebit = RegExp(
      r'\b(?:paid(?!\s+you)|sent(?!\s+you)|transferred\s+to|trf\s+to|purchase|'
      r'payment\s+(?:of|to)|payment\s+successful|txn\s+(?:of|for)|txn\s+(?:₹|rs|inr)|'
      r'transaction\s+(?:of|for)|transaction\s+number|used\s+(?:for|at)|'
      r'thank\s+you\s+for\s+using|done\s+at|'
      r'transferred\s+from\s+(?:your\s+)?(?:a/c|ac|acct|account))\b');
  static final _weakCredit = RegExp(
      r'\b(?:received|added\s+to|paid\s+you|sent\s+you|'
      r'transferred\s+from(?!\s+(?:your\s+)?(?:a/c|ac\b|acct|account)))');

  static PaymentDirection? detectDirection(String lower) =>
      _earliest(lower, _strongDebit, _strongCredit) ??
      _earliest(lower, _weakDebit, _weakCredit);

  static PaymentDirection? _earliest(String lower, RegExp debit, RegExp credit) {
    final d = _firstOutsideBalance(lower, debit);
    final c = _firstOutsideBalance(lower, credit);
    if (d == null && c == null) return null;
    if (c == null || (d != null && d < c)) return PaymentDirection.debit;
    return PaymentDirection.credit;
  }

  // "Bal: Rs.15000.00CR" describes the balance, not the payment.
  static int? _firstOutsideBalance(String lower, RegExp pattern) => pattern
      .allMatches(lower)
      .where((match) => !_isBalanceFigure(lower, match.start))
      .firstOrNull
      ?.start;

  // --- 3. Amount ---

  static const _number = r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)';
  static final _currencyFirst = RegExp('(?:₹|rs\\.?|inr|rupees)\\s*:?\\s*$_number');
  static final _currencyAfter =
      RegExp('(?<![x*0-9,.])$_number\\s*(?:₹|rs\\b|inr\\b|rupees)');
  static final _verbThenNumber = RegExp(
      '(?:debited|credited|deducted|withdrawn)\\s+(?:by|with|for|of)?\\s*$_number\\b');
  static final _balanceBefore =
      RegExp(r'(?:bal|balance|limit|avl|available|outstanding|due|min)[^0-9]{0,12}$');

  /// The first amount that isn't a balance/limit figure.
  static double? extractAmount(String lower) {
    final matches = [
      ..._currencyFirst.allMatches(lower),
      ..._currencyAfter.allMatches(lower),
    ]..sort((a, b) => a.start.compareTo(b.start));
    for (final match in matches) {
      if (_isBalanceFigure(lower, match.start) || _isSaving(lower, match.end)) continue;
      final value = _toAmount(match.group(1));
      if (value != null) return value;
    }
    return _toAmount(_verbThenNumber.firstMatch(lower)?.group(1));
  }

  /// An order receipt's labelled total ("Paid Via Bank ₹506", "Grand Total
  /// ₹506"). Receipts list item prices and "₹80 saved" before it, so the
  /// first amount would be wrong. Only used for emails.
  static double? extractReceiptTotal(String lower) =>
      _toAmount(_receiptTotal.allMatches(lower).lastOrNull?.group(1));

  static final _receiptTotal = RegExp(
      r'(?:paid\s+(?:via|using|by|with)\b[^\n₹0-9]{0,24}|amount\s+paid|total\s+paid|you\s+paid|'
      r'grand\s+total|order\s+total|bill\s+total|total\s+amount)'
      r'[^0-9₹\n]{0,6}\n?\s*(?:₹|rs\.?|inr)\s*:?\s*' '$_number');

  static bool _isBalanceFigure(String lower, int start) {
    final before = lower.substring(start < 24 ? 0 : start - 24, start);
    return _balanceBefore.hasMatch(before);
  }

  /// "₹80 saved on this order" is a discount, not money that moved.
  static bool _isSaving(String lower, int end) =>
      _savedAfter.hasMatch(lower.substring(end, end + 12 > lower.length ? lower.length : end + 12));
  static final _savedAfter = RegExp(r'^\s*(?:saved|off)\b');

  static double? _toAmount(String? raw) {
    final value = double.tryParse(raw?.replaceAll(',', '') ?? '');
    return (value == null || value <= 0) ? null : value;
  }

  // --- 4. Account tail and reference ---

  // "A/cX4821", "BOBCARD ending 5678", "a/c no. XX312225".
  static final _labelledTail = RegExp(
      r'(?:\b(?:a/c|acct|account|ac)|card)\.?\s*(?:no\.?|number|ending(?:\s+with|\s+in)?)?'
      r'\s*[:\-]?\s*(?:[x*.]+)?\s*([0-9]{3,6})\b');
  // "XX1234", "****5521", "...1234", "••5521".
  static final _maskedTail = RegExp(r'(?:[x*•·]{2,}|\.{2,})\s?([0-9]{3,6})\b');

  /// The first account/card mentioned is the user's own; later ones are
  /// usually the other party ("Sender A/c XXXX9108").
  static String? extractAccountTail(String lower) {
    final matches = [_labelledTail.firstMatch(lower), _maskedTail.firstMatch(lower)]
        .whereType<RegExpMatch>()
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final digits = matches.firstOrNull?.group(1);
    if (digits == null) return null;
    return digits.length > 4 ? digits.substring(digits.length - 4) : digits;
  }

  static final _labelledRef = RegExp(
      r'\b(?:upi\s*(?:ref(?:erence)?|txn|transaction)?|ref(?:erence)?|refno|rrn|utr|'
      r'txn|transaction)\s*(?:no|id|number|ref)?\.?\s*(?:is)?\s*[:#\-.]?\s*([0-9]{9,18})\b');
  static final _bareRrn = RegExp(r'(?<![0-9])([0-9]{12})(?![0-9])');

  static String? extractReference(String lower) =>
      (_labelledRef.firstMatch(lower) ?? _bareRrn.firstMatch(lower))?.group(1);

  // --- 5. Is there real evidence this is a bank/payment alert? ---

  static final _financialWords = RegExp(
      r'\b(?:a/c|acct|account|card|upi|bank|wallet|neft|imps|rtgs|vpa|txn|'
      r'transaction|nach|ecs|emi|atm|pos|ref|utr|rrn)\b');
  static final _businessSender = RegExp(
      r'^[a-z]{2}-[a-z0-9]{3,9}(?:-[a-z])?$|^[0-9]{4,6}$|'
      r'bank|card|upi|pay|credit|wallet|finance|sbi|hdfc|icici|axis|kotak',
      caseSensitive: false);

  static bool _hasFinancialEvidence(
      NotificationInput input, String lower, String? tail, String? reference) {
    if (tail != null || reference != null) return true;
    switch (AppKinds.of(input.app)) {
      case AppKind.chat:
        return false; // chats mentioning money need an a/c tail or ref
      case AppKind.sms:
        return _businessSender.hasMatch(input.title.trim()) &&
            _financialWords.hasMatch(lower);
      case AppKind.payment:
        return true;
      case AppKind.email:
      case AppKind.other:
        return _financialWords.hasMatch(lower);
    }
  }

  // --- 6. Payee ---

  // Ends a name: a joining word, punctuation, or a sentence-ending period.
  static const _end =
      r'(?=\s+(?:on|via|using|ref|refno|upi|from|for|dated|avl|bal|txn|thru|through|with|in|by|is|has|was|of|'
      r'to|refunded|credited|debited)\b'
      r'|[;,(\n!]|\.(?=\s|$|ref|bal|avl|info|not|call)|\s-|$)';

  // "UPI/P2M/627512346789/BLINKIT", "UPI/DR/651122780001/UK FOOD/UTIB"
  static const _upiPath = 'upi/(?:p2[am]/|dr/|cr/)?[0-9]{6,}/([^/\\n]+?)(?:/|\\.|\\n|\$)';
  // "NEFT Cr-CITI0100000-ACME TECHNOLOGIES-..." (an IFSC, then the name)
  static const _ifscPath =
      '(?:neft|imps|rtgs)\\s*(?:cr|dr)?[-/:]\\s*[a-z]{4}0[a-z0-9]{6}[-/](.+?)[-/]';
  static const _date = '[0-9]{1,2}[-/ ](?:[0-9]{1,2}|[a-z]{3})[-/ ][0-9]{2,4}';

  // Most specific first.
  static final _debitPayee = [
    RegExp('\\b(?:to|paid|sent)\\s+(?:vpa\\s+)?([a-z0-9._-]+@[a-z]+)', caseSensitive: false),
    RegExp(_upiPath, caseSensitive: false),
    RegExp(_ifscPath, caseSensitive: false),
    RegExp('(?:payment|txn|debit)\\s+of\\s+(?:₹|rs\\.?|inr)\\s*[0-9.,]+\\s+for\\s+(.+?)$_end',
        caseSensitive: false),
    RegExp('\\b(?:paid|sent|transferred|trf|transfer|payment(?:\\s+of\\s+\\S+)?|txn(?:\\s+of\\s+\\S+)?)'
        '\\s+to[\\s:]+(?:vpa\\s+|a/c\\s+)?(.+?)$_end', caseSensitive: false),
    // "@UPI_SURAKSHAA HEALTHCA 23-08-2025"
    RegExp('@\\s?(?:upi[_ ])?([a-z][a-z0-9 &._-]{1,30}?)\\s+[0-9]{1,2}[-/]', caseSensitive: false),
    RegExp('\\bat\\s+(.+?)$_end', caseSensitive: false),
    // "on 06-Sep-26 on Swiggy", "on BURGRILL 04-12-2025"
    RegExp('\\bon\\s+$_date\\s+(?:on|at)\\s+(.+?)$_end', caseSensitive: false),
    RegExp('\\bon\\s+([a-z][a-z0-9 &._-]{1,30}?)\\s+$_date', caseSensitive: false),
    // "ACH DR INW PAY/0000WD2C.../Grow"
    RegExp('(?:ach|nach|ecs)[^/\\n]{0,20}/[^/\\n]+/([a-z][^/\\n.]{1,30})', caseSensitive: false),
    // Multi-line card alerts: the line after the time is the merchant.
    RegExp('[0-9]{2}:[0-9]{2}(?::[0-9]{2})?(?:\\s*ist)?\\n([^\\n]{2,40})\\n', caseSensitive: false),
    RegExp(r'[;:]\s*([a-z][a-z0-9 &._@-]{1,40}?)\s+credited\b', caseSensitive: false),
    RegExp('\\btowards\\s+(.+?)$_end', caseSensitive: false),
    RegExp('\\bto[\\s:]+(?:vpa\\s+)?(.+?)$_end', caseSensitive: false),
    RegExp('\\binfo[:\\s]+([a-z][^.\\n]{1,30}?)$_end', caseSensitive: false),
  ];
  static final _creditPayee = [
    RegExp('\\b(?:from|by)\\s+(?:vpa\\s+)?([a-z0-9._-]+@[a-z]+)', caseSensitive: false),
    RegExp(r'([a-z]+(?:\s[a-z]+){0,3})\s+(?:paid|sent)\s+you', caseSensitive: false),
    RegExp(_upiPath, caseSensitive: false),
    RegExp(_ifscPath, caseSensitive: false),
    // "Info: NEFT-ACME CORP SALARY"
    RegExp('\\binfo[:\\s]+(?:neft|imps|rtgs|ach|nach)[-/:\\s]+(?:[a-z]{4}[0-9]+[-/])?(.+?)$_end',
        caseSensitive: false),
    RegExp('\\b(?:from|by)\\s+(?:vpa\\s+)?(.+?)$_end', caseSensitive: false),
  ];

  static String? extractPayee(String text, PaymentDirection direction) {
    final patterns =
        direction == PaymentDirection.debit ? _debitPayee : _creditPayee;
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(text)) {
        final name = cleanPayee(match.group(1));
        if (name != null) return name;
      }
    }
    return null;
  }

  static final _notAName = RegExp(
      r'^(?:your|you|a/c|ac|acct|account|the|xx|card|bank|upi|neft|imps|rtgs|self|'
      r'transfer|cash|atm|mobile|net\s?banking|wallet|on|rs|inr|my)\b',
      caseSensitive: false);
  static final _honorific = RegExp(r'^(?:mr|mrs|ms|m/s|dr)\.?\s+', caseSensitive: false);
  // The user's own card/account ("Credit Card x1234"), but not a shop such
  // as "Metro Card".
  static final _ownAccount = RegExp(
      r'\b(?:a/c|account)\b|\b(?:credit|debit|bank)\b.*\bcard\b|\bcard\s*(?:no\.?)?\s*[x*]*[0-9]',
      caseSensitive: false);

  /// Tidies a payee candidate; null if it isn't a plausible name.
  static String? cleanPayee(String? raw) {
    if (raw == null) return null;
    var name = raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[\s.,;:\-*]+$'), '')
        .replaceFirst(_honorific, '')
        .trim();
    if (name.length < 2 || _notAName.hasMatch(name)) return null;
    if (RegExp(r'^[0-9]').hasMatch(name)) return null; // a time, date or phone number
    if (_ownAccount.hasMatch(name)) {
      return null; // "AU Bank Credit Card x1234" is the user's card, not the payee
    }
    if (RegExp(r'[₹]|\brs\.?\s*\d|\binr\b', caseSensitive: false).hasMatch(name)) return null;
    final digits = name.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digits * 2 > name.length) return null;
    if (name.length > 40) name = name.substring(0, 40).trim();
    return _titleCaseIfShouting(name);
  }

  static String _titleCaseIfShouting(String name) {
    if (name.contains('@') || name != name.toUpperCase()) return name;
    return name.toLowerCase().replaceAllMapped(
        RegExp(r'(^|[\s&(/-])([a-z])'), (m) => '${m[1]}${m[2]!.toUpperCase()}');
  }

  static final _genericTitle = RegExp(
      r'google\s?pay|gpay|phonepe|paytm|cred|bhim|amazon|payment|transaction|'
      r'money|upi|alert|bank|successful|received|sent|paid|debited|credited|[₹0-9]',
      caseSensitive: false);

  /// UPI apps often put the payee alone in the title ("Sharma Store" /
  /// "You paid ₹250").
  static String? _senderName(NotificationInput input) {
    final title = input.title.trim();
    if (title.isEmpty || _genericTitle.hasMatch(title)) return null;
    return cleanPayee(title);
  }

  static String? _payeeFromTitle(NotificationInput input) {
    if (AppKinds.of(input.app) != AppKind.payment) return null;
    final title = input.title.trim();
    if (title.isEmpty || _genericTitle.hasMatch(title)) return null;
    return cleanPayee(title);
  }
}
