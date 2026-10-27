/// Reads numbers typed by a person, including Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩ and ۰۱۲۳۴۵۶۷۸۹), the Arabic decimal
/// separator (٫) and a decimal comma, so a student or instructor can type in their own digits.
abstract final class NumberParsing {
  /// Replaces every Arabic-Indic digit and separator with its ASCII form and removes spaces and thousands separators.
  static String normalize(String text) {
    final buffer = StringBuffer();
    for (final rune in text.trim().runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + rune - 0x06F0);
      } else if (rune == 0x066B || rune == 0x002C) {
        buffer.write('.');
      } else if (rune == 0x066C || rune == 0x0020 || rune == 0x00A0) {
        continue;
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// A whole number, or null when [text] is not one (a fraction such as "3.5" is not a whole number).
  static int? parseInt(String text) => int.tryParse(normalize(text));

  /// A number with an optional fraction, or null when [text] is not a plain number (no exponent, no "NaN").
  static double? parseDecimal(String text) {
    final normalized = normalize(text);
    if (!RegExp(r'^[0-9]+(\.[0-9]+)?$').hasMatch(normalized)) return null;
    return double.tryParse(normalized);
  }
}
