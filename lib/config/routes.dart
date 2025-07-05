import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/day_detail/day_detail_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/search/search_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String calendar = '/calendar';
  static const String dayDetail = '/day-detail';
  static const String settings = '/settings';
  static const String search = '/search';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      
      case calendar:
        return MaterialPageRoute(
          builder: (_) => const CalendarScreen(),
          settings: settings,
        );
      
      case dayDetail:
        final date = settings.arguments as DateTime?;
        return MaterialPageRoute(
          builder: (_) => DayDetailScreen(date: date ?? DateTime.now()),
          settings: settings,
        );
      
      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );
      
      case AppRoutes.search:
        return MaterialPageRoute(
          builder: (_) => const SearchScreen(),
          settings: settings,
        );
      
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Page not found'),
            ),
          ),
          settings: settings,
        );
    }
  }
}

/// Navigation utilities
class AppNavigation {
  static void pushToCalendar(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.calendar);
  }

  static void pushToDayDetail(BuildContext context, DateTime date) {
    Navigator.pushNamed(
      context, 
      AppRoutes.dayDetail,
      arguments: date,
    );
  }

  static void pushToSettings(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.settings);
  }

  static void pushToSearch(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.search);
  }
}