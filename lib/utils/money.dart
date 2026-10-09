import 'package:intl/intl.dart';

/// Rounds to whole paise. Amounts are stored as decimals (REAL); rounding
/// at every save and in totals keeps float noise (250.00000000003) from
/// ever reaching the database or the screen.
double roundMoney(double value) => (value * 100).round() / 100;

/// Sum of [values], rounded to paise.
double sumMoney(Iterable<double> values) =>
    roundMoney(values.fold(0.0, (total, v) => total + v));

final _whole = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _exact = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _compact = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 1);

/// The one way amounts are written: ₹1,23,450 for whole rupees,
/// ₹899.50 only when there are paise.
String formatMoney(double value) {
  final rounded = roundMoney(value);
  return rounded == rounded.roundToDouble() ? _whole.format(rounded) : _exact.format(rounded);
}

/// Short form for chart labels: ₹950, ₹1.6K, ₹2.4L.
String formatMoneyCompact(double value) =>
    value.abs() < 1000 ? formatMoney(value.roundToDouble()) : _compact.format(value);
