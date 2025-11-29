import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings state for the fasting companion app
class FastingSettings {
  final bool notificationsEnabled;
  final bool hourlyReminders;
  final bool milestoneReminders;
  final bool completionReminders;
  final bool vibrationEnabled;
  final bool soundEnabled;
  final String defaultFastTypeId;
  final bool showLiturgicalContent;
  final int timerUpdateInterval; // in seconds

  const FastingSettings({
    this.notificationsEnabled = true,
    this.hourlyReminders = true,
    this.milestoneReminders = true,
    this.completionReminders = true,
    this.vibrationEnabled = true,
    this.soundEnabled = false,
    this.defaultFastTypeId = 'intermittent_16_8',
    this.showLiturgicalContent = true,
    this.timerUpdateInterval = 60, // 1 minute default
  });

  FastingSettings copyWith({
    bool? notificationsEnabled,
    bool? hourlyReminders,
    bool? milestoneReminders,
    bool? completionReminders,
    bool? vibrationEnabled,
    bool? soundEnabled,
    String? defaultFastTypeId,
    bool? showLiturgicalContent,
    int? timerUpdateInterval,
  }) {
    return FastingSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      hourlyReminders: hourlyReminders ?? this.hourlyReminders,
      milestoneReminders: milestoneReminders ?? this.milestoneReminders,
      completionReminders: completionReminders ?? this.completionReminders,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      defaultFastTypeId: defaultFastTypeId ?? this.defaultFastTypeId,
      showLiturgicalContent:
          showLiturgicalContent ?? this.showLiturgicalContent,
      timerUpdateInterval: timerUpdateInterval ?? this.timerUpdateInterval,
    );
  }
}

/// Notifier for managing fasting settings
class FastingSettingsNotifier extends StateNotifier<FastingSettings> {
  static const String _keyNotifications = 'notifications_enabled';
  static const String _keyHourlyReminders = 'hourly_reminders';
  static const String _keyMilestoneReminders = 'milestone_reminders';
  static const String _keyCompletionReminders = 'completion_reminders';
  static const String _keyVibration = 'vibration_enabled';
  static const String _keySound = 'sound_enabled';
  static const String _keyDefaultFastType = 'default_fast_type';
  static const String _keyShowLiturgical = 'show_liturgical_content';
  static const String _keyTimerInterval = 'timer_update_interval';

  final SharedPreferences _prefs;

  FastingSettingsNotifier(this._prefs) : super(const FastingSettings()) {
    _loadSettings();
  }

  /// Load settings from SharedPreferences
  void _loadSettings() {
    state = FastingSettings(
      notificationsEnabled: _prefs.getBool(_keyNotifications) ?? true,
      hourlyReminders: _prefs.getBool(_keyHourlyReminders) ?? true,
      milestoneReminders: _prefs.getBool(_keyMilestoneReminders) ?? true,
      completionReminders: _prefs.getBool(_keyCompletionReminders) ?? true,
      vibrationEnabled: _prefs.getBool(_keyVibration) ?? true,
      soundEnabled: _prefs.getBool(_keySound) ?? false,
      defaultFastTypeId:
          _prefs.getString(_keyDefaultFastType) ?? 'intermittent_16_8',
      showLiturgicalContent: _prefs.getBool(_keyShowLiturgical) ?? true,
      timerUpdateInterval: _prefs.getInt(_keyTimerInterval) ?? 60,
    );
  }

  /// Toggle notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_keyNotifications, enabled);
    state = state.copyWith(notificationsEnabled: enabled);
  }

  /// Toggle hourly reminders
  Future<void> setHourlyReminders(bool enabled) async {
    await _prefs.setBool(_keyHourlyReminders, enabled);
    state = state.copyWith(hourlyReminders: enabled);
  }

  /// Toggle milestone reminders
  Future<void> setMilestoneReminders(bool enabled) async {
    await _prefs.setBool(_keyMilestoneReminders, enabled);
    state = state.copyWith(milestoneReminders: enabled);
  }

  /// Toggle completion reminders
  Future<void> setCompletionReminders(bool enabled) async {
    await _prefs.setBool(_keyCompletionReminders, enabled);
    state = state.copyWith(completionReminders: enabled);
  }

  /// Toggle vibration
  Future<void> setVibrationEnabled(bool enabled) async {
    await _prefs.setBool(_keyVibration, enabled);
    state = state.copyWith(vibrationEnabled: enabled);
  }

  /// Toggle sound
  Future<void> setSoundEnabled(bool enabled) async {
    await _prefs.setBool(_keySound, enabled);
    state = state.copyWith(soundEnabled: enabled);
  }

  /// Set default fast type
  Future<void> setDefaultFastType(String fastTypeId) async {
    await _prefs.setString(_keyDefaultFastType, fastTypeId);
    state = state.copyWith(defaultFastTypeId: fastTypeId);
  }

  /// Toggle liturgical content
  Future<void> setShowLiturgicalContent(bool show) async {
    await _prefs.setBool(_keyShowLiturgical, show);
    state = state.copyWith(showLiturgicalContent: show);
  }

  /// Set timer update interval (in seconds)
  Future<void> setTimerUpdateInterval(int seconds) async {
    await _prefs.setInt(_keyTimerInterval, seconds);
    state = state.copyWith(timerUpdateInterval: seconds);
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await _prefs.clear();
    state = const FastingSettings();
  }
}

/// Provider for SharedPreferences
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

/// Provider for fasting settings
final fastingSettingsProvider =
    StateNotifierProvider<FastingSettingsNotifier, FastingSettings>((ref) {
  // Wait for SharedPreferences to be available
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  return prefsAsync.when(
    data: (prefs) => FastingSettingsNotifier(prefs),
    loading: () => FastingSettingsNotifier(
      MockSharedPreferences(),
    ), // Temporary during loading
    error: (error, stack) => FastingSettingsNotifier(MockSharedPreferences()),
  );
});

/// Mock SharedPreferences for loading state
class MockSharedPreferences implements SharedPreferences {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == const Symbol('getBool')) {
      return null;
    }
    if (invocation.memberName == const Symbol('getString')) {
      return null;
    }
    if (invocation.memberName == const Symbol('getInt')) {
      return null;
    }
    return super.noSuchMethod(invocation);
  }
}
