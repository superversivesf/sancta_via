/// High-performance Catholic liturgical calendar library with embedded Dart data.
///
/// This library provides zero-overhead access to Catholic liturgical calendar data
/// by embedding all data directly as Dart objects, eliminating JSON parsing and
/// providing unprecedented performance.
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
///
/// // No initialization needed - data is embedded!
/// final today = LiturgicalCalendarService.getCurrentDay();
/// print('Today is ${today?.season}: ${today?.celebration.name}');
///
/// // Get upcoming feasts
/// final feasts = LiturgicalCalendarService.getUpcomingFeasts();
/// for (final feast in feasts) {
///   print('${feast.date}: ${feast.celebration.name}');
/// }
///
/// // Advanced queries
/// final maryFeasts = LiturgicalCalendarService.searchCelebrations('Mary');
/// final adventDays = LiturgicalCalendarService.getDaysForSeason(2025, 'Advent');
/// ```
library sancta_via_liturgical_calendar;

// Models
export 'src/models/liturgical_celebration.dart';
export 'src/models/liturgical_cycle.dart';
export 'src/models/liturgical_year_info.dart';
export 'src/models/liturgical_day_data.dart';
export 'src/models/liturgical_calendar_data.dart';
export 'src/models/liturgical_index.dart';

// Enums
export 'src/enums/liturgical_season.dart';
export 'src/enums/celebration_rank.dart';

// Services
export 'src/services/liturgical_calendar_service.dart';

// Generated data (embedded Dart objects)
export 'src/data/generated/generated_liturgical_data.dart';

// Exceptions
export 'src/exceptions/liturgical_calendar_exception.dart';
