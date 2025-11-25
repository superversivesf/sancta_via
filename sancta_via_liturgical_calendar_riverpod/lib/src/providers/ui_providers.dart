import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'liturgical_providers.dart';

/// Provider for liturgical color as Flutter Color
final liturgicalColorProvider = Provider<Color>((ref) {
  final colorString = ref.watch(currentLiturgicalColorProvider);
  return _getLiturgicalColor(colorString);
});

/// Provider for liturgical color by date
final liturgicalColorByDateProvider = Provider.family<Color, DateTime>((
  ref,
  date,
) {
  final day = ref.watch(liturgicalDayProvider(date));
  return _getLiturgicalColor(day?.celebration.color);
});

/// Provider for season-based theme data
final liturgicalThemeProvider = Provider<ThemeData>((ref) {
  final color = ref.watch(liturgicalColorProvider);
  final season = ref.watch(currentLiturgicalSeasonProvider);

  return ThemeData(
    primarySwatch: _createMaterialColor(color),
    colorScheme: ColorScheme.fromSeed(
      seedColor: color,
      brightness: _getSeasonBrightness(season),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: color,
      foregroundColor: _getContrastingTextColor(color),
    ),
  );
});

/// Provider for current celebration display text
final currentCelebrationDisplayProvider = Provider<String>((ref) {
  final currentDay = ref.watch(currentLiturgicalDayProvider);
  if (currentDay == null) return 'No liturgical data available';

  return currentDay.displayName;
});

/// Provider for formatted liturgical information
final liturgicalInfoProvider = Provider<Map<String, String>>((ref) {
  final currentDay = ref.watch(currentLiturgicalDayProvider);
  if (currentDay == null) {
    return {
      'date': DateTime.now().toString().split(' ')[0],
      'celebration': 'No data available',
      'season': 'Unknown',
      'rank': 'Unknown',
      'color': 'Unknown',
    };
  }

  return {
    'date': currentDay.date,
    'celebration': currentDay.celebration.name,
    'season': currentDay.season,
    'rank': currentDay.celebration.rank,
    'color': currentDay.celebration.colorName,
    'cycle': currentDay.liturgicalYear.cycle.value,
    'psalterWeek': currentDay.psalterWeek.value,
  };
});

/// Provider for upcoming celebrations formatted for UI
final upcomingCelebrationsUIProvider = Provider<List<Map<String, String>>>((
  ref,
) {
  final upcoming = ref.watch(upcomingFeastsProvider(30));

  return upcoming
      .map(
        (day) => {
          'date': day.date,
          'name': day.celebration.name,
          'rank': day.celebration.rank,
          'daysUntil': DateTime.parse(
            day.date,
          ).difference(DateTime.now()).inDays.toString(),
        },
      )
      .toList();
});

/// Provider for liturgical calendar widget state
final liturgicalCalendarStateProvider = Provider<Map<String, dynamic>>((ref) {
  final currentDay = ref.watch(currentLiturgicalDayProvider);
  final color = ref.watch(liturgicalColorProvider);
  final upcoming = ref.watch(upcomingFeastsProvider(7));

  return {
    'hasData': currentDay != null,
    'currentDay': currentDay,
    'liturgicalColor': color,
    'upcomingCount': upcoming.length,
    'isPrioritized': currentDay?.celebration.prioritized ?? false,
    'season': currentDay?.season ?? 'Unknown',
  };
});

/// Provider for season-appropriate icons
final seasonIconProvider = Provider<IconData>((ref) {
  final season = ref.watch(currentLiturgicalSeasonProvider);
  return _getSeasonIcon(season);
});

/// Provider for rank-appropriate icons
final rankIconProvider = Provider<IconData>((ref) {
  final currentDay = ref.watch(currentLiturgicalDayProvider);
  final rank = currentDay?.celebration.rank;
  return _getRankIcon(rank);
});

/// Provider for liturgical notification data
final liturgicalNotificationProvider = Provider<Map<String, dynamic>?>((ref) {
  final currentDay = ref.watch(currentLiturgicalDayProvider);
  if (currentDay == null || !currentDay.celebration.prioritized) return null;

  return {
    'title': currentDay.celebration.name,
    'subtitle': '${currentDay.season} • ${currentDay.celebration.rank}',
    'color': ref.watch(liturgicalColorProvider),
    'priority': currentDay.celebration.rank == 'SOLEMNITY' ? 'high' : 'normal',
  };
});

/// Helper function to convert liturgical color string to Flutter Color
Color _getLiturgicalColor(String? colorString) {
  switch (colorString?.toUpperCase()) {
    case 'WHITE':
      return Colors.grey.shade100;
    case 'RED':
      return Colors.red.shade700;
    case 'GREEN':
      return Colors.green.shade700;
    case 'PURPLE':
      return Colors.purple.shade700;
    case 'ROSE':
      return Colors.pink.shade300;
    case 'GOLD':
      return Colors.amber.shade600;
    default:
      return Colors.grey.shade500;
  }
}

/// Helper function to create MaterialColor from Color
MaterialColor _createMaterialColor(Color color) {
  final int red = (color.r * 255.0).round().clamp(0, 255);
  final int green = (color.g * 255.0).round().clamp(0, 255);
  final int blue = (color.b * 255.0).round().clamp(0, 255);

  final Map<int, Color> shades = {
    50: Color.fromRGBO(red, green, blue, .1),
    100: Color.fromRGBO(red, green, blue, .2),
    200: Color.fromRGBO(red, green, blue, .3),
    300: Color.fromRGBO(red, green, blue, .4),
    400: Color.fromRGBO(red, green, blue, .5),
    500: Color.fromRGBO(red, green, blue, .6),
    600: Color.fromRGBO(red, green, blue, .7),
    700: Color.fromRGBO(red, green, blue, .8),
    800: Color.fromRGBO(red, green, blue, .9),
    900: Color.fromRGBO(red, green, blue, 1),
  };

  return MaterialColor(color.toARGB32(), shades);
}

/// Helper function to determine season brightness
Brightness _getSeasonBrightness(String? season) {
  switch (season?.toLowerCase()) {
    case 'advent':
    case 'lent':
      return Brightness.dark;
    default:
      return Brightness.light;
  }
}

/// Helper function to get contrasting text color
Color _getContrastingTextColor(Color backgroundColor) {
  final luminance = backgroundColor.computeLuminance();
  return luminance > 0.5 ? Colors.black : Colors.white;
}

/// Helper function to get season-appropriate icon
IconData _getSeasonIcon(String? season) {
  switch (season?.toLowerCase()) {
    case 'advent':
      return Icons.auto_awesome; // Star/hope
    case 'christmas':
    case 'christmastide':
      return Icons.celebration; // Celebration
    case 'lent':
      return Icons.self_improvement; // Reflection/prayer
    case 'easter':
    case 'eastertide':
      return Icons.wb_sunny; // Resurrection/light
    case 'ordinary time':
    case 'early ordinary time':
      return Icons.calendar_today; // Regular time
    default:
      return Icons.church; // Generic liturgical
  }
}

/// Helper function to get rank-appropriate icon
IconData _getRankIcon(String? rank) {
  switch (rank?.toUpperCase()) {
    case 'SOLEMNITY':
      return Icons.star; // Highest rank
    case 'FEAST':
      return Icons.celebration; // Major celebration
    case 'MEMORIAL':
      return Icons.event; // Memorial
    case 'OPTIONAL_MEMORIAL':
    case 'OPT_MEMORIAL':
      return Icons.event_available; // Optional
    default:
      return Icons.today; // Regular day
  }
}
