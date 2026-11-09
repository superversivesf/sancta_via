/// Season-driven content selection rules for Catholic devotions.
///
/// Selects the mysteries of the Holy Rosary, the Marian prayer at midday
/// (Angelus or Regina Caeli), and the seasonal Marian antiphon for a date,
/// driven by the liturgical data from `sancta_via_liturgical_calendar`
/// (whose `LiturgicalDayData.seasonKey` values in the embedded 2024-2035
/// data are `Advent`, `Christmastide`, `Early Ordinary Time`, `Later
/// Ordinary Time`, `Lent`, `Holy Week`, and `Easter`; the rule set
/// tolerates the alternate spellings `Christmas`, `Eastertide`, and
/// `Pentecost` for future data revisions).
library;

import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';

/// The four sets of mysteries of the Holy Rosary.
///
/// Weekday (ferial) assignment: Monday and Saturday [joyful], Tuesday and
/// Friday [sorrowful], Wednesday [glorious], Thursday [luminous].
enum MysterySet { joyful, sorrowful, glorious, luminous }

/// Returns the Rosary mysteries for [date], taking [day]'s liturgical season
/// into account.
///
/// On a Sunday, the weekday assignment is overridden by the season: Advent
/// and Christmas Sundays pray the joyful mysteries, a Lenten Sunday the
/// sorrowful mysteries, and every other Sunday (including Holy Week and
/// Easter) the glorious mysteries. Without liturgical data the Sunday
/// falls back to the glorious set. Weekdays use the fixed ferial map,
/// regardless of season.
MysterySet rosaryMysteriesFor(DateTime date, LiturgicalDayData? day) {
  if (date.weekday == DateTime.sunday) {
    // The override keys off the day's seasonKey, never off weekday inference.
    final String seasonKey = day?.seasonKey ?? '';
    if (_isAdventOrChristmasSeason(seasonKey)) {
      return MysterySet.joyful;
    }
    if (seasonKey == 'Lent') {
      return MysterySet.sorrowful;
    }
    return MysterySet.glorious;
  }

  // Weekday map, independent of liturgical season.
  final int weekday = date.weekday;
  if (weekday == DateTime.monday || weekday == DateTime.saturday) {
    return MysterySet.joyful;
  }
  if (weekday == DateTime.tuesday || weekday == DateTime.friday) {
    return MysterySet.sorrowful;
  }
  if (weekday == DateTime.wednesday) {
    return MysterySet.glorious;
  }
  return MysterySet.luminous; // Thursday.
}

/// Returns the midday Marian prayer key for [date]: `'regina_caeli'`
/// throughout the Easter season (through Pentecost inclusive), otherwise
/// `'angelus'`.
///
/// The Easter window keys off [day]'s `seasonKey`. When no liturgical data
/// is available for the date, [date] cannot resolve a season and the
/// Angelus remains the default.
String angelusPrayerFor(DateTime date, LiturgicalDayData? day) {
  return _isEasterSeason(day?.seasonKey ?? '') ? 'regina_caeli' : 'angelus';
}

/// Returns the Marian antiphon key for [day]'s date:
///
/// - `'alma_redemptoris_mater'` — First Vespers of Advent I through Candlemas
///   (February 2, inclusive). This window is decided by date (December,
///   January, February through the 2nd, plus late-November Advent days),
///   because the Christmas season and pre-Lent February span several keys.
/// - `'ave_regina_caelorum'` — from Candlemas until Holy Week is reached:
///   post-Epiphany February 3 onward and Lent.
/// - `'regina_caeli'` — Easter season through Pentecost (by `seasonKey`).
/// - `'salve_regina'` — the remainder of Ordinary Time, from Pentecost to
///   Advent I and after Candlemas. Also the default when [day] is null.
/// - `''` — Holy Week through the Triduum: Compline of those days is not
///   closed with a Marian antiphon; the caller should omit the prayer.
String marianAntiphonFor(LiturgicalDayData? day) {
  if (day == null) {
    return 'salve_regina';
  }

  final String seasonKey = day.seasonKey;

  // Holy Week through the Triduum carries no Marian antiphon.
  if (seasonKey == 'Holy Week' || seasonKey == 'Triduum') {
    return '';
  }

  // Easter Vigil through Pentecost: the Regina Caeli.
  if (_isEasterSeason(seasonKey)) {
    return 'regina_caeli';
  }

  // Date-range window: Advent through Candlemas. December, January, and
  // February through the 2nd belong to the Alma Redemptoris Mater era.
  // (day.dateTime parses the embedded 'yyyy-mm-dd' string as a local date.)
  final DateTime date = day.dateTime;
  final bool inAlmaWindow =
      date.month == DateTime.december ||
      date.month == DateTime.january ||
      (date.month == DateTime.february && date.day <= 2);
  if (inAlmaWindow) {
    return 'alma_redemptoris_mater';
  }

  // Advent days fall in late November (as early as November 27); they
  // precede the December rule above.
  if (seasonKey == 'Advent' || seasonKey == 'Christmastide') {
    return 'alma_redemptoris_mater';
  }

  // From Candlemas to Holy Week: post-Epiphany February and Lent.
  if (seasonKey == 'Lent' || seasonKey == 'Early Ordinary Time') {
    return 'ave_regina_caelorum';
  }

  // Ordinary Time from Pentecost to Advent I.
  return 'salve_regina';
}

/// Whether [seasonKey] marks the seasons whose Sundays pray the joyful
/// mysteries (Advent through Christmas).
bool _isAdventOrChristmasSeason(String seasonKey) {
  return seasonKey == 'Advent' ||
      seasonKey == 'Christmastide' ||
      seasonKey == 'Christmas';
}

/// Whether [seasonKey] marks the Easter season, from the Easter Vigil to
/// Pentecost inclusive.
bool _isEasterSeason(String seasonKey) {
  return seasonKey == 'Easter' ||
      seasonKey == 'Eastertide' ||
      seasonKey == 'Pentecost';
}
