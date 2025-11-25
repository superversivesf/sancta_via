import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import '../models/prayer.dart';

class PrayerOfTheDayService {
  // Main method to get prayer of the day
  static Prayer? selectPrayerOfTheDay(
    DateTime date,
    LiturgicalDayData liturgicalDay,
    List<Prayer> allPrayers,
  ) {
    // Filter liturgical prayers for selection
    final liturgicalPrayers = allPrayers.where((p) => p.isLiturgical).toList();

    if (liturgicalPrayers.isEmpty) return null;

    // 1. HIGH PRIORITY: Major Feast Days
    final feastPrayer = _getFeastDayPrayer(liturgicalDay, liturgicalPrayers);
    if (feastPrayer != null) return feastPrayer;

    // 2. MEDIUM PRIORITY: Liturgical Seasons
    final seasonalPrayer = _getSeasonalPrayer(
      liturgicalDay,
      liturgicalPrayers,
      date,
    );
    if (seasonalPrayer != null) return seasonalPrayer;

    // 3. DEFAULT: Weekly rotation with variety
    return _getOrdinaryTimePrayer(date, liturgicalPrayers);
  }

  // Handle specific feast days and solemnities
  static Prayer? _getFeastDayPrayer(
    LiturgicalDayData liturgicalDay,
    List<Prayer> prayers,
  ) {
    // Major Solemnities get specific prayers
    if (liturgicalDay.isSolemnity &&
        liturgicalDay.celebration.name.isNotEmpty) {
      // Christmas Season
      if (liturgicalDay.celebration.name.contains('Nativity') ||
          liturgicalDay.celebration.name.contains('Christmas')) {
        return _findPrayerByPreference(prayers, [
          'gloria_in_excelsis',
          'veni_creator_spiritus',
        ]);
      }

      // Easter
      if (liturgicalDay.celebration.name.contains('Easter')) {
        return _findPrayerByPreference(prayers, [
          'regina_caeli',
          'gloria_in_excelsis',
        ]);
      }

      // Marian Feasts
      if (liturgicalDay.celebration.name.contains('Mary') ||
          liturgicalDay.celebration.name.contains('Immaculate') ||
          liturgicalDay.celebration.name.contains('Assumption') ||
          liturgicalDay.celebration.name.contains('Annunciation')) {
        return _findPrayerByPreference(prayers, [
          'hail_mary',
          'prayer_to_immaculate_heart',
          'memorare',
        ]);
      }

      // St. Joseph
      if (liturgicalDay.celebration.name.contains('Joseph')) {
        return _findPrayerById(prayers, 'prayer_to_st_joseph');
      }

      // All Saints
      if (liturgicalDay.celebration.name.contains('All Saints')) {
        return _findPrayerByPreference(prayers, [
          'prayer_to_st_michael',
          'prayer_for_pope_formal',
        ]);
      }
    }

    return null;
  }

  // Handle liturgical seasons
  static Prayer? _getSeasonalPrayer(
    LiturgicalDayData liturgicalDay,
    List<Prayer> prayers,
    DateTime date,
  ) {
    final season = LiturgicalSeason.fromString(liturgicalDay.season);
    if (season == null) return null;

    switch (season) {
      case LiturgicalSeason.advent:
        // Rotate through preparation prayers
        final adventPrayers = [
          'veni_creator_spiritus',
          'morning_thanksgiving',
          'morning_offering',
        ];
        return _rotatePrayerByDay(prayers, adventPrayers, date);

      case LiturgicalSeason.christmas:
      case LiturgicalSeason.christmastide:
        // Christmas joy and praise
        final christmasPrayers = [
          'gloria_in_excelsis',
          'hail_mary',
          'prayer_to_st_joseph',
        ];
        return _rotatePrayerByDay(prayers, christmasPrayers, date);

      case LiturgicalSeason.lent:
        // Penitential and reflective prayers
        final lentPrayers = [
          'act_of_contrition',
          'prayer_to_sacred_heart',
          'eternal_rest',
        ];
        return _rotatePrayerByDay(prayers, lentPrayers, date);

      case LiturgicalSeason.triduum:
        // Sacred Triduum - most solemn prayers
        if (liturgicalDay.celebration.name.contains('Thursday')) {
          return _findPrayerById(prayers, 'anima_christi');
        } else if (liturgicalDay.celebration.name.contains('Friday')) {
          return _findPrayerById(prayers, 'prayer_to_sacred_heart');
        } else {
          return _findPrayerById(prayers, 'compline_final_prayer');
        }

      case LiturgicalSeason.easter:
      case LiturgicalSeason.eastertide:
        // Easter joy and resurrection
        final easterPrayers = ['regina_caeli', 'gloria_in_excelsis', 'sanctus'];
        return _rotatePrayerByDay(prayers, easterPrayers, date);

      case LiturgicalSeason.pentecost:
        return _findPrayerById(prayers, 'veni_creator_spiritus');

      case LiturgicalSeason.ordinaryTime:
      case LiturgicalSeason.earlyOrdinaryTime:
        // Continue to ordinary time logic
        return null;

      case LiturgicalSeason.holyWeek:
        // Holy Week prayers
        final holyWeekPrayers = [
          'prayer_to_sacred_heart',
          'act_of_contrition',
          'eternal_rest',
        ];
        return _rotatePrayerByDay(prayers, holyWeekPrayers, date);
    }
  }

  // Handle Ordinary Time with weekly patterns
  static Prayer _getOrdinaryTimePrayer(DateTime date, List<Prayer> prayers) {
    // Weekly pattern for Ordinary Time
    final weeklyPatterns = {
      DateTime.sunday: ['apostles_creed', 'nicene_creed', 'gloria_in_excelsis'],
      DateTime.monday: [
        'morning_offering',
        'morning_thanksgiving',
        'prayer_to_st_joseph',
      ],
      DateTime.tuesday: [
        'prayer_to_st_michael',
        'guardian_angel_prayer',
        'st_anthony_lost_things',
      ],
      DateTime.wednesday: [
        'prayer_for_pope_formal',
        'veni_creator_spiritus',
        'eternal_rest',
      ],
      DateTime.thursday: ['anima_christi', 'sanctus', 'agnus_dei'],
      DateTime.friday: [
        'act_of_contrition',
        'prayer_to_sacred_heart',
        'st_francis_peace_prayer',
      ],
      DateTime.saturday: [
        'hail_mary',
        'memorare',
        'prayer_to_immaculate_heart',
      ],
    };

    final dayPrayers =
        weeklyPatterns[date.weekday] ?? weeklyPatterns[DateTime.sunday]!;
    return _rotatePrayerByWeek(prayers, dayPrayers, date);
  }

  // Helper methods
  static Prayer? _findPrayerById(List<Prayer> prayers, String id) {
    try {
      return prayers.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  static Prayer? _findPrayerByPreference(
    List<Prayer> prayers,
    List<String> preferredIds,
  ) {
    for (final id in preferredIds) {
      final prayer = _findPrayerById(prayers, id);
      if (prayer != null) return prayer;
    }
    return null;
  }

  static Prayer _rotatePrayerByDay(
    List<Prayer> prayers,
    List<String> prayerIds,
    DateTime date,
  ) {
    final availablePrayers = prayerIds
        .map((id) => _findPrayerById(prayers, id))
        .where((p) => p != null)
        .cast<Prayer>()
        .toList();

    if (availablePrayers.isEmpty) {
      return prayers.first; // Fallback
    }

    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    return availablePrayers[dayOfYear % availablePrayers.length];
  }

  static Prayer _rotatePrayerByWeek(
    List<Prayer> prayers,
    List<String> prayerIds,
    DateTime date,
  ) {
    final availablePrayers = prayerIds
        .map((id) => _findPrayerById(prayers, id))
        .where((p) => p != null)
        .cast<Prayer>()
        .toList();

    if (availablePrayers.isEmpty) {
      return prayers.first; // Fallback
    }

    // Use week of year for slower rotation
    final weekOfYear = ((date.difference(DateTime(date.year, 1, 1)).inDays) / 7)
        .floor();
    return availablePrayers[weekOfYear % availablePrayers.length];
  }
}
