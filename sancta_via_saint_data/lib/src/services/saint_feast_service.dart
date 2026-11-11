// Feast-day key helpers for the saint dataset.
//
// Every saint stores its feast day as an `MM-DD` key (see Saint.feastDay);
// this service builds those keys from calendar dates and classifies leap
// years. Dart wraps `DateTime(year, 2, 29)` to March 1 in non-leap years, so
// a Feb-29 celebration has no key through this service in those years; the
// fallback to the previous day's celebration lives at the feast-lookup
// side, not here.

/// Builds `MM-DD` feast keys from calendar dates.
class SaintFeastService {
  /// Not instantiable; static members only.
  SaintFeastService._();

  /// Returns the zero-padded `MM-DD` key for [date].
  ///
  /// Leap-year February 29 is kept verbatim (`2028-02-29` → `02-29`);
  /// non-leap years cannot produce it because Dart wraps the date to
  /// March 1.
  static String feastKeyForDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$month-$day';
  }

  /// True when [year] is a leap year in the proleptic Gregorian calendar.
  ///
  /// Divisible by 4, except century years, which must be divisible by 400
  /// (2028 leap, 1900 not, 2000 leap).
  static bool isLeapYear(int year) {
    if (year % 4 != 0) {
      return false;
    }
    if (year % 100 != 0) {
      return true;
    }
    return year % 400 == 0;
  }
}
