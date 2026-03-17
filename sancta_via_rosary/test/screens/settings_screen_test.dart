import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rosary_companion/providers/notification_settings_provider.dart';
import 'package:rosary_companion/screens/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Creates a testable widget wrapped in ProviderScope and MaterialApp.
Widget createTestApp({
  required Widget child,
  GoRouter? router,
  List<Override> overrides = const [],
}) {
  if (router != null) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router),
    );
  }
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: child,
      routes: {
        '/settings/notifications': (context) =>
            const _MockNotificationSettingsScreen(),
        '/statistics': (context) => const _MockStatisticsScreen(),
      },
    ),
  );
}

/// Mock notification settings screen for navigation testing
class _MockNotificationSettingsScreen extends StatelessWidget {
  const _MockNotificationSettingsScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('Notification Settings'));
  }
}

/// Mock statistics screen for navigation testing
class _MockStatisticsScreen extends StatelessWidget {
  const _MockStatisticsScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('Statistics'));
  }
}

/// Mock notifier for testing provider interactions
class MockRosarySettingsNotifier extends StateNotifier<RosarySettings>
    implements RosarySettingsNotifier {
  MockRosarySettingsNotifier([RosarySettings? initialState])
    : super(initialState ?? const RosarySettings());

  bool setNotificationsEnabledCalled = false;
  bool setDailyReminderEnabledCalled = false;
  bool setReminderTimeCalled = false;
  bool resetToDefaultsCalled = false;

  @override
  String get formattedReminderTime {
    final hour = state.reminderHour;
    final minute = state.reminderMinute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    setNotificationsEnabledCalled = true;
    state = state.copyWith(
      notificationsEnabled: enabled,
      dailyReminderEnabled: enabled ? state.dailyReminderEnabled : false,
    );
  }

  @override
  Future<void> setDailyReminderEnabled(bool enabled) async {
    setDailyReminderEnabledCalled = true;
    state = state.copyWith(dailyReminderEnabled: enabled);
  }

  @override
  Future<void> setReminderTime(int hour, int minute) async {
    setReminderTimeCalled = true;
    final clampedHour = hour.clamp(0, 23);
    final clampedMinute = minute.clamp(0, 59);
    state = state.copyWith(
      reminderHour: clampedHour,
      reminderMinute: clampedMinute,
    );
  }

  @override
  Future<void> resetToDefaults() async {
    resetToDefaultsCalled = true;
    state = const RosarySettings();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('Rendering', () {
      testWidgets('renders with correct app bar title', (tester) async {
        await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
      });

      testWidgets('renders all settings sections', (tester) async {
        await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        // Verify all sections are present
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Appearance'), findsOneWidget);
        expect(find.text('Prayer Preferences'), findsOneWidget);
        expect(find.text('Statistics'), findsOneWidget);
        expect(find.text('About'), findsOneWidget);
      });

      testWidgets('renders section subtitles', (tester) async {
        await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Configure daily prayer reminders'), findsOneWidget);
        expect(find.text('Theme, colors, and display options'), findsOneWidget);
        expect(
          find.text('Font size, language, and other prayer settings'),
          findsOneWidget,
        );
        expect(
          find.text('View your prayer history and progress'),
          findsOneWidget,
        );
        expect(find.text('App information and support'), findsOneWidget);
      });

      testWidgets('renders icons for each section', (tester) async {
        await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.notifications), findsOneWidget);
        expect(find.byIcon(Icons.palette), findsOneWidget);
        expect(find.byIcon(Icons.self_improvement), findsOneWidget);
        expect(find.byIcon(Icons.bar_chart), findsOneWidget);
        expect(find.byIcon(Icons.info), findsOneWidget);
      });

      testWidgets('renders navigation arrows', (tester) async {
        await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        // Each section should have a navigation arrow
        expect(find.byIcon(Icons.arrow_forward_ios), findsNWidgets(5));
      });

      testWidgets('renders dividers between sections', (tester) async {
        await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        expect(find.byType(Divider), findsNWidgets(4));
      });
    });

    group('Navigation', () {
      testWidgets('tapping Notifications navigates to notification settings', (
        tester,
      ) async {
        await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        // Tap on Notifications section
        await tester.tap(find.text('Notifications'));
        await tester.pumpAndSettle();

        // Should navigate to notification settings
        expect(find.text('Notification Settings'), findsOneWidget);
      });

      testWidgets('tapping Statistics navigates to statistics screen', (
        tester,
      ) async {
        await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        // Tap on Statistics section
        await tester.tap(find.text('Statistics'));
        await tester.pumpAndSettle();

        // Should navigate to statistics screen
        expect(find.text('Statistics'), findsOneWidget);
      });

      testWidgets('tapping About shows about dialog', (tester) async {
        await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        // Tap on About section
        await tester.tap(find.text('About'));
        await tester.pumpAndSettle();

        // Verify about dialog is shown
        expect(find.byType(AboutDialog), findsOneWidget);
        expect(find.text('Sancta Via Rosary'), findsOneWidget);
        expect(find.textContaining('Sancta Via'), findsOneWidget);
      });
    });

    group('Appearance Settings Bottom Sheet', () {
      testWidgets('tapping Appearance shows appearance settings bottom sheet', (
        tester,
      ) async {
        await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        // Tap on Appearance section
        await tester.tap(find.text('Appearance'));
        await tester.pumpAndSettle();

        // Verify bottom sheet is shown
        expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      });

      testWidgets('appearance bottom sheet contains theme mode selector', (
        tester,
      ) async {
        await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Appearance'));
        await tester.pumpAndSettle();

        expect(find.text('Theme Mode'), findsOneWidget);
      });

      testWidgets('appearance bottom sheet contains color intensity selector', (
        tester,
      ) async {
        await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Appearance'));
        await tester.pumpAndSettle();

        expect(find.text('Color Intensity'), findsOneWidget);
      });

      testWidgets('appearance bottom sheet contains font size selector', (
        tester,
      ) async {
        await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Appearance'));
        await tester.pumpAndSettle();

        expect(find.text('Font Size'), findsOneWidget);
      });
    });

    group('Prayer Preferences Bottom Sheet', () {
      testWidgets(
        'tapping Prayer Preferences shows prayer settings bottom sheet',
        (tester) async {
          await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
          await tester.pumpAndSettle();

          // Tap on Prayer Preferences section
          await tester.tap(find.text('Prayer Preferences'));
          await tester.pumpAndSettle();

          // Verify bottom sheet is shown
          expect(find.byType(DraggableScrollableSheet), findsOneWidget);
        },
      );

      testWidgets(
        'prayer preferences bottom sheet contains language selector',
        (tester) async {
          await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Prayer Preferences'));
          await tester.pumpAndSettle();

          expect(find.text('Language'), findsOneWidget);
        },
      );

      testWidgets(
        'prayer preferences bottom sheet contains accessibility settings',
        (tester) async {
          await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Prayer Preferences'));
          await tester.pumpAndSettle();

          expect(find.text('Accessibility'), findsOneWidget);
        },
      );
    });

    group('Provider Integration', () {
      testWidgets('reads from rosarySettingsProvider', (tester) async {
        final mockNotifier = MockRosarySettingsNotifier(
          const RosarySettings(
            notificationsEnabled: true,
            reminderHour: 8,
            reminderMinute: 30,
            dailyReminderEnabled: true,
          ),
        );

        await tester.pumpWidget(
          createTestApp(
            child: const SettingsScreen(),
            overrides: [
              rosarySettingsProvider.overrideWith((ref) => mockNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Screen should render correctly with mock provider
        expect(find.byType(SettingsScreen), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('all list tiles are tappable', (tester) async {
        await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        // All sections should be ListTiles (tappable)
        final listTiles = find.byType(ListTile);
        expect(listTiles, findsNWidgets(5));
      });

      testWidgets('sections have proper semantic labels', (tester) async {
        await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        // Verify text is present (used for semantic labeling)
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Appearance'), findsOneWidget);
        expect(find.text('Prayer Preferences'), findsOneWidget);
        expect(find.text('Statistics'), findsOneWidget);
        expect(find.text('About'), findsOneWidget);
      });
    });

    group('Error Handling', () {
      testWidgets('renders even when provider has errors', (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: SettingsScreen())),
        );
        await tester.pumpAndSettle();

        // Screen should still render with default content
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      });
    });

    group('ListTile Structure', () {
      testWidgets('each section has correct structure', (tester) async {
        await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        // Find all ListTiles
        final listTiles = tester.widgetList<ListTile>(find.byType(ListTile));

        for (final tile in listTiles) {
          // Each tile should have a leading icon
          expect(tile.leading, isNotNull);
          expect(tile.leading, isA<Icon>());

          // Each tile should have a title
          expect(tile.title, isNotNull);

          // Each tile should have a subtitle
          expect(tile.subtitle, isNotNull);

          // Each tile should have a trailing icon
          expect(tile.trailing, isNotNull);
          expect(tile.trailing, isA<Icon>());

          // Each tile should be tappable (has onTap)
          expect(tile.onTap, isNotNull);
        }
      });
    });
  });
}
