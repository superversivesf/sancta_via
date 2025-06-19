/// Riverpod providers for liturgical_calendar with reactive state management.
///
/// This library provides comprehensive Riverpod providers for the liturgical_calendar
/// package, enabling reactive Flutter apps that automatically update when liturgical
/// data changes. Perfect for Catholic apps that need to respond to date changes,
/// seasonal transitions, and feast day occurrences.
///
/// ## Features
///
/// - 🔄 **Reactive date updates** - Automatically refreshes at midnight
/// - ⚡ **Zero-overhead providers** - Built on embedded liturgical data
/// - 🎨 **Flutter UI integration** - Colors, themes, and icons
/// - 📅 **Comprehensive coverage** - Current day, upcoming feasts, seasons
/// - 🔍 **Search and filtering** - Find celebrations, saints, and more
/// - 📊 **Analytics and insights** - Liturgical year progress and statistics
/// - 🔔 **Notification support** - Reminders for important celebrations
///
/// ## Quick Start
///
/// ```dart
/// import 'package:flutter_riverpod/flutter_riverpod.dart';
/// import 'package:liturgical_calendar_riverpod/liturgical_calendar_riverpod.dart';
///
/// class LiturgicalWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final today = ref.watch(currentLiturgicalDayProvider);
///     final color = ref.watch(liturgicalColorProvider);
///     
///     return Card(
///       color: color.withOpacity(0.1),
///       child: ListTile(
///         title: Text(today?.celebration.name ?? 'Loading...'),
///         subtitle: Text(today?.season ?? ''),
///         trailing: Icon(ref.watch(seasonIconProvider)),
///       ),
///     );
///   }
/// }
/// ```
///
/// ## Core Providers
///
/// ### Current Day & Date Reactivity
/// - `currentDateProvider` - Stream of current date that updates at midnight
/// - `currentLiturgicalDayProvider` - Current liturgical day with auto-updates
/// - `currentLiturgicalSeasonProvider` - Current season
/// - `currentLiturgicalColorProvider` - Current liturgical color
///
/// ### Liturgical Data Access
/// - `liturgicalDayProvider(date)` - Get specific day by date
/// - `upcomingFeastsProvider(days)` - Upcoming celebrations
/// - `searchCelebrationsProvider(query, year)` - Search celebrations
/// - `seasonDaysProvider(year, season)` - Days in specific season
///
/// ### Flutter UI Integration
/// - `liturgicalColorProvider` - Current color as Flutter Color
/// - `liturgicalThemeProvider` - Season-based ThemeData
/// - `seasonIconProvider` - Appropriate icon for current season
/// - `liturgicalInfoProvider` - Formatted info for display
///
/// ### Analytics & Utilities
/// - `globalStatisticsProvider` - Overall liturgical data statistics
/// - `liturgicalAnalyticsProvider(year)` - Year-specific analytics
/// - `nextMajorCelebrationProvider` - Next important celebration
/// - `liturgicalRemindersProvider` - Upcoming celebration reminders
///
library liturgical_calendar_riverpod;

// Core liturgical providers
export 'src/providers/liturgical_providers.dart';

// Flutter UI integration providers
export 'src/providers/ui_providers.dart';

// Utility and specialized providers
export 'src/providers/utility_providers.dart';

// Re-export the base liturgical_calendar for convenience
export 'package:liturgical_calendar/liturgical_calendar.dart';

// Re-export riverpod for convenience
export 'package:flutter_riverpod/flutter_riverpod.dart'
    show 
      Provider, 
      StreamProvider, 
      FutureProvider,
      StateProvider,
      StateNotifierProvider,
      ChangeNotifierProvider,
      ConsumerWidget,
      ConsumerStatefulWidget,
      Consumer,
      WidgetRef,
      ProviderScope,
      ProviderContainer;
