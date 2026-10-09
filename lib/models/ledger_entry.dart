import '../utils/money.dart';
import 'expense.dart';
import 'income.dart';

/// One row of the money list: an expense, an income entry, or a split
/// payment (several expenses that are one payment).
class LedgerEntry {
  final Expense? expense;
  final Income? income;

  /// Every part of a split payment, largest first; empty otherwise.
  final List<Expense> parts;

  const LedgerEntry.expense(Expense this.expense)
      : income = null,
        parts = const [];
  const LedgerEntry.income(Income this.income)
      : expense = null,
        parts = const [];

  /// [splitParts] in any order; the first part (lowest id) leads.
  LedgerEntry.split(List<Expense> splitParts)
      : expense = splitParts.reduce((a, b) => (a.id ?? 0) <= (b.id ?? 0) ? a : b),
        income = null,
        parts = [...splitParts]..sort((a, b) => b.amount.compareTo(a.amount));

  bool get isIncome => income != null;
  bool get isSplit => parts.isNotEmpty;
  int get id => expense?.id ?? income!.id!;
  double get amount => isSplit ? sumMoney(parts.map((p) => p.amount)) : expense?.amount ?? income!.amount;
  DateTime get date => expense?.date ?? income!.date;

  /// The category (expenses), source (income), or a split's categories.
  String get label => isSplit ? labels.join(', ') : expense?.category ?? income!.source;

  /// Every category this entry counts toward.
  List<String> get labels => isSplit
      ? {for (final p in parts) p.category}.toList()
      : [expense?.category ?? income!.source];

  /// What this entry adds to [category] (a split's part for it, or all).
  double amountIn(String category) => isSplit
      ? sumMoney(parts.where((p) => p.category == category).map((p) => p.amount))
      : (label == category ? amount : 0);

  /// Who was paid (or paid you), when known.
  String? get payee => _clean(expense?.payee ?? income?.payee);

  /// The user's own note, when there is one (a split's first part's note).
  String? get note => _clean(expense?.notes ?? income?.notes);

  static String? _clean(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Both lists merged, newest first; a split's parts become one entry.
  static List<LedgerEntry> merge(List<Expense> expenses, List<Income> income) {
    final splits = <int, List<Expense>>{};
    final all = <LedgerEntry>[];
    for (final e in expenses) {
      final splitId = e.splitId;
      if (splitId == null) {
        all.add(LedgerEntry.expense(e));
      } else {
        splits.putIfAbsent(splitId, () => []).add(e);
      }
    }
    all.addAll([for (final parts in splits.values) LedgerEntry.split(parts)]);
    all.addAll([for (final i in income) LedgerEntry.income(i)]);
    all.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
    return all;
  }
}
