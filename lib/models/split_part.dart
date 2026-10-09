import '../utils/money.dart';

/// One category's share of a split payment, as entered on the split screen.
class SplitPart {
  final String category;
  final double amount;
  final String? note;

  const SplitPart(this.category, this.amount, {this.note});

  SplitPart copyWith({double? amount, String? note}) =>
      SplitPart(category, amount ?? this.amount, note: note ?? this.note);
}

/// The split screen's rule: the first part is "the rest". The user types
/// the other parts; the first gets whatever is left of [total].
List<SplitPart> withRemainder(double total, List<SplitPart> parts) {
  if (parts.isEmpty) return parts;
  final others = sumMoney(parts.skip(1).map((p) => p.amount));
  return [parts.first.copyWith(amount: roundMoney(total - others)), ...parts.skip(1)];
}

/// Why [parts] (already passed through [withRemainder]) can't be saved,
/// or null when they can.
String? splitError(double total, List<SplitPart> parts) {
  if (parts.length < 2) return 'Pick at least 2 categories';
  if (parts.skip(1).any((p) => p.amount <= 0)) return 'Enter an amount for every part';
  if (parts.first.amount <= 0) {
    return 'The parts add up to more than ${formatMoney(total)}';
  }
  if (sumMoney(parts.map((p) => p.amount)) != roundMoney(total)) {
    return 'The parts must add up to ${formatMoney(total)}';
  }
  return null;
}
