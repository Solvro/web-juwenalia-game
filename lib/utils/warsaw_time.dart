import 'package:intl/intl.dart';

/// Helpers for treating Directus event times as **Europe/Warsaw**
/// regardless of the user's device timezone.
///
/// Directus stores `time` / `date` fields as naive wall-clock strings
/// (e.g. `"16:30:00"` + `"2026-05-13"`). The festival happens in
/// Wrocław, so those values are always Warsaw local time. Without this
/// helper the parser would treat them as device-local time, which
/// breaks "is this happening now?" comparisons and time displays for
/// any user not physically in Poland.
///
/// We don't ship the full IANA database — Poland's DST rule is the
/// standard EU one (CET / CEST), so we compute the offset for any
/// given instant directly. Good enough for the festival window and any
/// foreseeable rescheduling.
class WarsawTime {
  const WarsawTime._();

  static const Duration _cet = Duration(hours: 1);
  static const Duration _cest = Duration(hours: 2);

  /// Returns the UTC offset that Europe/Warsaw was on at the given
  /// absolute moment.
  static Duration offsetAt(DateTime instant) {
    final utc = instant.toUtc();
    return _isDstAt(utc) ? _cest : _cet;
  }

  /// EU DST: starts at 01:00 UTC on the last Sunday of March, ends at
  /// 01:00 UTC on the last Sunday of October.
  static bool _isDstAt(DateTime utc) {
    final year = utc.year;
    final dstStart = _lastSundayOfMonth(
      year,
      DateTime.march,
    ).add(const Duration(hours: 1));
    final dstEnd = _lastSundayOfMonth(
      year,
      DateTime.october,
    ).add(const Duration(hours: 1));
    return !utc.isBefore(dstStart) && utc.isBefore(dstEnd);
  }

  static DateTime _lastSundayOfMonth(int year, int month) {
    final firstNext = month == DateTime.december
        ? DateTime.utc(year + 1, DateTime.january, 1)
        : DateTime.utc(year, month + 1, 1);
    final lastDay = firstNext.subtract(const Duration(days: 1));
    final daysBack = lastDay.weekday % 7; // Sunday == 7 → 0
    return DateTime.utc(year, month, lastDay.day - daysBack);
  }

  /// Parses a naive ISO timestamp ("YYYY-MM-DDTHH:MM:SS", no zone) as
  /// Europe/Warsaw wall-clock and returns the absolute UTC moment it
  /// represents.
  ///
  /// Each candidate UTC moment (one for CET, one for CEST) is checked
  /// against the actual DST rules at that moment, and the candidate
  /// whose offset is self-consistent wins. Around the spring-forward
  /// gap and autumn fall-back overlap one candidate is picked
  /// deterministically (CEST and CET respectively), matching the
  /// behaviour of standard tz libraries.
  static DateTime? parseNaiveAsWarsaw(String s) {
    final wallAsUtc = DateTime.tryParse('${s}Z');
    if (wallAsUtc == null) return null;
    // Try CET interpretation first: if Warsaw was on CET at the
    // resulting UTC instant, that's our answer.
    final candidateCet = wallAsUtc.subtract(_cet);
    if (!_isDstAt(candidateCet)) return candidateCet;
    // Otherwise the wall-clock falls inside DST → use CEST.
    return wallAsUtc.subtract(_cest);
  }

  /// Returns a `DateTime` whose component fields (year/month/day/hour…)
  /// read as Warsaw wall-clock time. Useful for [DateFormat] which
  /// reads fields directly. The returned value should NOT be used for
  /// absolute comparisons — use the original [instant] for that.
  static DateTime asWarsawWallClock(DateTime instant) {
    final utc = instant.toUtc();
    return utc.add(offsetAt(utc));
  }

  /// Formats [instant] in Europe/Warsaw time using [pattern].
  static String format(DateTime instant, String pattern, [String? locale]) {
    return DateFormat(pattern, locale).format(asWarsawWallClock(instant));
  }
}
