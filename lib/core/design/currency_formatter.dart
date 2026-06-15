import 'package:intl/intl.dart';

/// Formats integer-cent amounts for display.
///
/// All money display in the app MUST use this class — never format cents
/// directly in widgets. See docs/contracts.md §12.
abstract final class CurrencyFormatter {
  static final _nf = NumberFormat.currency(symbol: '€', decimalDigits: 2);

  /// Returns '€12.50' for 1250 cents.
  static String format(int cents) => _nf.format(cents / 100);

  /// Returns '12.50' for 1250 cents (no symbol, e.g. for text inputs).
  static String formatAmount(int cents) => (cents / 100).toStringAsFixed(2);

  /// Parses a user-entered amount string to cents. Returns null on bad input.
  static int? parseToCents(String input) {
    final cleaned = input.trim().replaceAll(',', '.');
    final value = double.tryParse(cleaned);
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }
}
