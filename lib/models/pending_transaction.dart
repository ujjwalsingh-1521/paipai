import '../utils/money.dart';

/// A payment detected from a notification, waiting for (or already given)
/// a category. Rows stay after being handled so later alerts for the same
/// payment can be recognised as duplicates.
class PendingTransaction {
  final int? id;
  final double amount;
  final String type;
  final String? merchant;
  final String? upiRef;
  final String? accountTail;
  final String? category;
  final String? source;
  final String rawMessage;
  final String sender;
  final int confidence;
  final DateTime detectedAt;
  final bool isProcessed;
  final int? createdExpenseId;
  final int? createdIncomeId;

  /// Android package of the app whose notification reported it.
  final String? sourceApp;

  /// How many alerts (SMS, UPI app, email...) were merged into this one.
  final int seenCount;

  /// Merged by amount+time from the same app without a matching reference,
  /// so it might really have been two payments; the review sheet offers a split.
  final bool maybeMultiple;

  PendingTransaction({
    this.id,
    required this.amount,
    required this.type,
    this.merchant,
    this.upiRef,
    this.accountTail,
    this.category,
    this.source,
    required this.rawMessage,
    required this.sender,
    required this.confidence,
    required this.detectedAt,
    this.isProcessed = false,
    this.createdExpenseId,
    this.createdIncomeId,
    this.sourceApp,
    this.seenCount = 1,
    this.maybeMultiple = false,
  });

  bool get isDebit => type == 'debit';
  bool get isCredit => type == 'credit';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': roundMoney(amount),
      'type': type,
      'merchant': merchant,
      'upi_ref': upiRef,
      'account_tail': accountTail,
      'category': category,
      'source': source,
      'raw_message': rawMessage,
      'sender': sender,
      'confidence': confidence,
      'detected_at': detectedAt.toIso8601String(),
      'is_processed': isProcessed ? 1 : 0,
      'created_expense_id': createdExpenseId,
      'created_income_id': createdIncomeId,
      'source_app': sourceApp,
      'seen_count': seenCount,
      'maybe_multiple': maybeMultiple ? 1 : 0,
    };
  }

  factory PendingTransaction.fromMap(Map<String, dynamic> map) {
    return PendingTransaction(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      merchant: map['merchant'] as String?,
      upiRef: map['upi_ref'] as String?,
      accountTail: map['account_tail'] as String?,
      category: map['category'] as String?,
      source: map['source'] as String?,
      rawMessage: map['raw_message'] as String,
      sender: map['sender'] as String,
      confidence: map['confidence'] as int,
      detectedAt: DateTime.parse(map['detected_at'] as String),
      isProcessed: (map['is_processed'] as int) == 1,
      createdExpenseId: map['created_expense_id'] as int?,
      createdIncomeId: map['created_income_id'] as int?,
      sourceApp: map['source_app'] as String?,
      seenCount: map['seen_count'] as int? ?? 1,
      maybeMultiple: (map['maybe_multiple'] as int? ?? 0) == 1,
    );
  }

  PendingTransaction copyWith({
    int? id,
    String? merchant,
    String? upiRef,
    String? accountTail,
    String? category,
    String? source,
    bool? isProcessed,
    int? createdExpenseId,
    int? createdIncomeId,
    int? seenCount,
    bool? maybeMultiple,
    String? rawMessage,
  }) {
    return PendingTransaction(
      id: id ?? this.id,
      amount: amount,
      type: type,
      merchant: merchant ?? this.merchant,
      upiRef: upiRef ?? this.upiRef,
      accountTail: accountTail ?? this.accountTail,
      category: category ?? this.category,
      source: source ?? this.source,
      rawMessage: rawMessage ?? this.rawMessage,
      sender: sender,
      confidence: confidence,
      detectedAt: detectedAt,
      isProcessed: isProcessed ?? this.isProcessed,
      createdExpenseId: createdExpenseId ?? this.createdExpenseId,
      createdIncomeId: createdIncomeId ?? this.createdIncomeId,
      sourceApp: sourceApp,
      seenCount: seenCount ?? this.seenCount,
      maybeMultiple: maybeMultiple ?? this.maybeMultiple,
    );
  }
}
