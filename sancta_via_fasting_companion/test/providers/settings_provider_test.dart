import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_fasting_companion/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    // Set up mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('FastingSettings', () {
    test('should have correct default values', () {
      const settings = FastingSettings();

      expect(settings.notificationsEnabled, isTrue);
      expect(settings.hourlyReminders, isTrue);
      expect(settings.milestoneReminders, isTrue);
      expect(settings.completionReminders, isTrue);
      expect(settings.vibrationEnabled, isTrue);
      expect(settings.soundEnabled, isFalse);
      expect(settings.defaultFastTypeId, 'intermittent_16_8');
      expect(settings.showLiturgicalContent, isTrue);
      expect(settings.timerUpdateInterval, 60);
    });

    test('copyWith should create modified copy', () {
      const original = FastingSettings();
      final modified = original.copyWith(
        notificationsEnabled: false,
        soundEnabled: true,
      );

      expect(modified.notificationsEnabled, isFalse);
      expect(modified.soundEnabled, isTrue);
      expect(modified.hourlyReminders, isTrue); // Unchanged
    });
  });

  group('FastingSettingsNotifier', () {
    test('should load default settings', () {
      final settings = container.read(fastingSettingsProvider);

      expect(settings.notificationsEnabled, isTrue);
      expect(settings.defaultFastTypeId, 'intermittent_16_8');
    });

    test('should update notifications setting', () async {
      final notifier = container.read(fastingSettingsProvider.notifier);

      await notifier.setNotificationsEnabled(false);

      final settings = container.read(fastingSettingsProvider);
      expect(settings.notificationsEnabled, isFalse);
    });

    test('should update hourly reminders setting', () async {
      final notifier = container.read(fastingSettingsProvider.notifier);

      await notifier.setHourlyReminders(false);

      final settings = container.read(fastingSettingsProvider);
      expect(settings.hourlyReminders, isFalse);
    });

    test('should update milestone reminders setting', () async {
      final notifier = container.read(fastingSettingsProvider.notifier);

      await notifier.setMilestoneReminders(false);

      final settings = container.read(fastingSettingsProvider);
      expect(settings.milestoneReminders, isFalse);
    });

    test('should update completion reminders setting', () async {
      final notifier = container.read(fastingSettingsProvider.notifier);

      await notifier.setCompletionReminders(false);

      final settings = container.read(fastingSettingsProvider);
      expect(settings.completionReminders, isFalse);
    });

    test('should update vibration setting', () async {
      final notifier = container.read(fastingSettingsProvider.notifier);

      await notifier.setVibrationEnabled(false);

      final settings = container.read(fastingSettingsProvider);
      expect(settings.vibrationEnabled, isFalse);
    });

    test('should update sound setting', () async {
      final notifier = container.read(fastingSettingsProvider.notifier);

      await notifier.setSoundEnabled(true);

      final settings = container.read(fastingSettingsProvider);
      expect(settings.soundEnabled, isTrue);
    });

    test('should update default fast type', () async {
      final notifier = container.read(fastingSettingsProvider.notifier);

      await notifier.setDefaultFastType('daily_24hr');

      final settings = container.read(fastingSettingsProvider);
      expect(settings.defaultFastTypeId, 'daily_24hr');
    });

    test('should update liturgical content setting', () async {
      final notifier = container.read(fastingSettingsProvider.notifier);

      await notifier.setShowLiturgicalContent(false);

      final settings = container.read(fastingSettingsProvider);
      expect(settings.showLiturgicalContent, isFalse);
    });

    test('should update timer interval', () async {
      final notifier = container.read(fastingSettingsProvider.notifier);

      await notifier.setTimerUpdateInterval(30);

      final settings = container.read(fastingSettingsProvider);
      expect(settings.timerUpdateInterval, 30);
    });

    test('should reset to defaults', () async {
      final notifier = container.read(fastingSettingsProvider.notifier);

      // Change some settings
      await notifier.setNotificationsEnabled(false);
      await notifier.setSoundEnabled(true);
      await notifier.setDefaultFastType('daily_24hr');

      // Reset
      await notifier.resetToDefaults();

      final settings = container.read(fastingSettingsProvider);
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.soundEnabled, isFalse);
      expect(settings.defaultFastTypeId, 'intermittent_16_8');
    });

    test('should persist settings to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = container.read(fastingSettingsProvider.notifier);

      await notifier.setNotificationsEnabled(false);

      final stored = prefs.getBool('notifications_enabled');
      expect(stored, isFalse);
    });

    test('should load settings from SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();

      // Manually set a value
      await prefs.setBool('notifications_enabled', false);
      await prefs.setString('default_fast_type', 'daily_24hr');

      // Create new container to reload settings
      final newContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );

      final settings = newContainer.read(fastingSettingsProvider);
      expect(settings.notificationsEnabled, isFalse);
      expect(settings.defaultFastTypeId, 'daily_24hr');

      newContainer.dispose();
    });
  });

  group('MockSharedPreferences', () {
    test('should handle missing values gracefully', () {
      final mock = MockSharedPreferences();

      // These should return null without throwing
      expect(mock.getBool('test'), isNull);
      expect(mock.getString('test'), isNull);
      expect(mock.getInt('test'), isNull);
    });
  });
}
