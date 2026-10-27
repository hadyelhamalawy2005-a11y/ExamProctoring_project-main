import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Shows moments in the device's own time zone, in the language of the screen.
abstract final class DateFormatting {
  /// "Oct 27, 2026, 2:30 PM" in the device zone.
  static String dateTime(BuildContext context, DateTime moment) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).add_jm().format(moment.toLocal());
  }

  /// "Oct 27, 2026" in the device zone.
  static String date(BuildContext context, DateTime moment) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).format(moment.toLocal());
  }

  /// The device zone as "UTC+02:00 (Egypt Standard Time)" for [moment], so a time is never ambiguous.
  static String zone(DateTime moment) {
    final local = moment.toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final total = offset.abs();
    final hours = total.inHours.toString().padLeft(2, '0');
    final minutes = (total.inMinutes % 60).toString().padLeft(2, '0');
    final name = local.timeZoneName;
    return 'UTC$sign$hours:$minutes${name.isEmpty ? '' : ' ($name)'}';
  }
}
