/// Catholic liturgical calendar library with date calculations, feast detection, and liturgical data.
///
/// This library provides a comprehensive set of tools for working with the Catholic liturgical calendar,
/// including date calculations, feast detection, liturgical seasons, and detailed daily liturgical information.
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:liturgical_calendar/liturgical_calendar.dart';
///
/// // Initialize with a data loader (implementation depends on platform)
/// await LiturgicalCalendarService.initialize(myDataLoader);
///
/// // Get today's liturgical information
/// final today = await LiturgicalCalendarService.getCurrentDay();
/// print('Today is ${today?.season}: ${today?.celebration.name}');
///
/// // Get upcoming feasts
/// final feasts = await LiturgicalCalendarService.getUpcomingFeasts();
/// for (final feast in feasts) {
///   print('${feast.date}: ${feast.celebration.name}');
/// }
/// ```
library;

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
export 'src/services/data_loader.dart';

// Exceptions
export 'src/exceptions/liturgical_calendar_exception.dart';