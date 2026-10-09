import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database_helper.dart';
import '../models/balance_start.dart';

/// The bank balance the user set (null until they do). Home adds and
/// subtracts everything recorded since.
final balanceStartProvider =
    AsyncNotifierProvider<BalanceStartNotifier, BalanceStart?>(BalanceStartNotifier.new);

class BalanceStartNotifier extends AsyncNotifier<BalanceStart?> {
  static const _key = 'balance_start';
  static const _skippedKey = 'balance_prompt_skipped';
  final _db = DatabaseHelper();

  @override
  Future<BalanceStart?> build() async => BalanceStart.decode(await _db.getSetting(_key));

  /// "My balance right now is [amount]".
  Future<void> setBalance(double amount) async {
    final start = BalanceStart(
      amount: amount,
      setAt: DateTime.now(),
      lastExpenseId: await _db.maxId('expenses'),
      lastIncomeId: await _db.maxId('income'),
    );
    await _db.setSetting(_key, start.encode());
    state = AsyncData(start);
  }

  /// Whether to ask "What's your current bank balance?" on app open.
  Future<bool> shouldPrompt() async =>
      (await future) == null && await _db.getSetting(_skippedKey) != 'true';

  Future<void> skipPrompt() => _db.setSetting(_skippedKey, 'true');
}
