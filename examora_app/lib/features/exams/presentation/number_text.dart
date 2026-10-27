/// A number for display: a whole number without ".0", otherwise with at most two decimals and no trailing zeros.
String formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  final text = value.toStringAsFixed(2);
  return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
}
