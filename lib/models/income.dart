import '../utils/money.dart';

class Income {
  final int? id;
  final double amount;
  final String source;
  final DateTime date;
  /// Who the money came from (from a captured payment, or typed).
  final String? payee;

  /// The user's own note; separate from [payee].
  final String? notes;

  Income({
    this.id,
    required this.amount,
    required this.source,
    required this.date,
    this.payee,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': roundMoney(amount),
      'source': source,
      'date': date.toIso8601String(),
      'payee': payee,
      'notes': notes,
    };
  }

  factory Income.fromMap(Map<String, dynamic> map) {
    return Income(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      source: map['source'] as String,
      date: DateTime.parse(map['date'] as String),
      payee: map['payee'] as String?,
      notes: map['notes'] as String?,
    );
  }
}

const List<Map<String, dynamic>> defaultIncomeSourceData = [
  {'name': 'Salary', 'emoji': 'icon:account_balance_wallet', 'color': 0xFF2ECC71},
  {'name': 'Freelance', 'emoji': 'icon:laptop', 'color': 0xFF3B86FF},
  {'name': 'Investment', 'emoji': 'icon:trending_up', 'color': 0xFF845EC2},
  {'name': 'Business', 'emoji': 'icon:storefront', 'color': 0xFF4ECDC4},
  {'name': 'Gift', 'emoji': 'icon:card_giftcard', 'color': 0xFFFF6F91},
  {'name': 'Refund', 'emoji': 'icon:autorenew', 'color': 0xFFFFBE0B},
  {'name': 'Rental', 'emoji': 'icon:house', 'color': 0xFFFF8E53},
  {'name': 'Other', 'emoji': 'icon:more_horiz', 'color': 0xFF9B9B9B},
];
