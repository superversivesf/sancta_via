/// Gregorian computus: the date of Easter Sunday (Western reckoning).
///
/// Implements the Meeus/Jones/Butcher algorithm, the canonical integer-only
/// formula for Gregorian Easter. The intermediate variables (`a` through `m`)
/// follow the lettered symbols of the published algorithm so the code can be
/// checked line-by-line against the source formula.
library;

/// Returns Easter Sunday (Western, Gregorian) for [year] as a local date.
///
/// The result is a `DateTime` constructed with `DateTime(year, month, day)`,
/// i.e. local midnight, never a parsed or UTC-shifted date.
///
/// [year] must be between 1900 and 2400 inclusive; otherwise an
/// [ArgumentError] is thrown.
DateTime easterSundayFor(int year) {
  if (year < 1900 || year > 2400) {
    throw ArgumentError.value(
      year,
      'year',
      'must be between 1900 and 2400 inclusive',
    );
  }

  // Meeus/Jones/Butcher algorithm (Gregorian Easter):
  // a     the remainder of year / 19
  // b, c  the century and the year-of-century
  // d, e  their remainders when divided by 4
  // f, g  epact correction terms
  // h     the paschal full moon offset within its 30-day cycle
  // i, k  the year-of-century divided by and modulo 4
  // l     the days from the paschal full moon to the next Sunday
  // m     the epact 451-correction term
  final int a = year % 19;
  final int b = year ~/ 100;
  final int c = year % 100;
  final int d = b ~/ 4;
  final int e = b % 4;
  final int f = (b + 8) ~/ 25;
  final int g = (b - f + 1) ~/ 3;
  final int h = (19 * a + b - d - g + 15) % 30;
  final int i = c ~/ 4;
  final int k = c % 4;
  final int l = (32 + 2 * e + 2 * i - h - k) % 7;
  final int m = (a + 11 * h + 22 * l) ~/ 451;
  final int month = (h + l - 7 * m + 114) ~/ 31;
  final int day = (h + l - 7 * m + 114) % 31 + 1;

  return DateTime(year, month, day);
}
