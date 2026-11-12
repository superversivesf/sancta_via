import 'package:flutter/material.dart';

import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

/// Default missed-day policy applied to enrolled programs that do not carry
/// their own strict/permissive override.
const String defaultMissedDayPolicy = 'permissive';

/// Faithful default for a [TimeOfDay] field when stored data is missing or
/// malformed.
TimeOfDay _timeFromJson(Object? value, TimeOfDay fallback) {
  if (value is! Map) {
    return fallback;
  }
  final hour = (value['hour'] as num?)?.toInt() ?? fallback.hour;
  final minute = (value['minute'] as num?)?.toInt() ?? fallback.minute;
  return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
}

Map<String, dynamic> _timeToJson(TimeOfDay time) {
  return <String, dynamic>{'hour': time.hour, 'minute': time.minute};
}

/// Devotionals app settings: the shared [BaseSettingsModel] plus the
/// app-specific anchor times, reminder toggles, and display preferences.
///
/// Persisted JSON shape (storage key lives on [DevotionsSettingsNotifier]):
/// every [TimeOfDay] field is stored as `{hour, minute}` — no `DateTime`
/// dependency.
@immutable
class DevotionsAppSettings {
  /// Base settings shared across all Sancta Via apps.
  final BaseSettingsModel baseSettings;

  /// Morning Angelus anchor time (default 6:00).
  final TimeOfDay angelusMorning;

  /// Midday Angelus anchor time (default 12:00).
  final TimeOfDay angelusNoon;

  /// Evening Angelus anchor time (default 18:00).
  final TimeOfDay angelusEvening;

  /// Divine Mercy hour anchor time (default 15:00).
  final TimeOfDay mercyHour;

  /// Whether the morning reminder notification is enabled (default off;
  /// onboarding asks the user to enable it and request permission).
  final bool morningReminderEnabled;

  /// Whether the evening reminder notification is enabled (default off;
  /// onboarding asks the user to enable it and request permission).
  final bool eveningReminderEnabled;

  /// Whether meal & night anchor items appear (default off — the settings
  /// screen carries an explicit "off by default" warning for it).
  final bool nightItemsEnabled;

  /// Whether the Today pipeline includes the Angelus anchors (default on).
  final bool enableAngelusAnchors;

  /// Whether the Today pipeline includes the Divine Mercy hour anchor
  /// (default on).
  final bool enableMercyHourAnchor;

  /// Default missed-day restart policy for enrolled programs: `'permissive'`
  /// (resume) rather than `'strict'` (reset), unless a program overrides it.
  final String missedDayDefaultPolicy;

  /// Whether Latin display enrichments are shown (default on).
  final bool latinDisplayEnabled;

  /// Whether the Luminous mysteries set is used (default on).
  final bool luminousSetEnabled;

  /// Whether the first-launch onboarding walkthrough has completed.
  final bool onboardingComplete;

  const DevotionsAppSettings({
    required this.baseSettings,
    this.angelusMorning = const TimeOfDay(hour: 6, minute: 0),
    this.angelusNoon = const TimeOfDay(hour: 12, minute: 0),
    this.angelusEvening = const TimeOfDay(hour: 18, minute: 0),
    this.mercyHour = const TimeOfDay(hour: 15, minute: 0),
    this.morningReminderEnabled = false,
    this.eveningReminderEnabled = false,
    this.nightItemsEnabled = false,
    this.enableAngelusAnchors = true,
    this.enableMercyHourAnchor = true,
    this.missedDayDefaultPolicy = defaultMissedDayPolicy,
    this.latinDisplayEnabled = true,
    this.luminousSetEnabled = true,
    this.onboardingComplete = false,
  });

  /// Create default Devotionals app settings.
  factory DevotionsAppSettings.defaults() {
    return DevotionsAppSettings(baseSettings: BaseSettingsModel.defaults());
  }

  /// Create from JSON map; missing or malformed fields fall back to defaults
  /// (times clamp into their valid ranges).
  factory DevotionsAppSettings.fromJson(Map<String, dynamic> json) {
    final defaults = DevotionsAppSettings.defaults();
    return DevotionsAppSettings(
      baseSettings: json['baseSettings'] is Map<String, dynamic>
          ? BaseSettingsModel.fromJson(
              json['baseSettings'] as Map<String, dynamic>,
            )
          : defaults.baseSettings,
      angelusMorning: _timeFromJson(
        json['angelusMorning'],
        defaults.angelusMorning,
      ),
      angelusNoon: _timeFromJson(json['angelusNoon'], defaults.angelusNoon),
      angelusEvening: _timeFromJson(
        json['angelusEvening'],
        defaults.angelusEvening,
      ),
      mercyHour: _timeFromJson(json['mercyHour'], defaults.mercyHour),
      morningReminderEnabled: json['morningReminderEnabled'] as bool? ?? false,
      eveningReminderEnabled: json['eveningReminderEnabled'] as bool? ?? false,
      nightItemsEnabled: json['nightItemsEnabled'] as bool? ?? false,
      enableAngelusAnchors: json['enableAngelusAnchors'] as bool? ?? true,
      enableMercyHourAnchor: json['enableMercyHourAnchor'] as bool? ?? true,
      missedDayDefaultPolicy:
          json['missedDayDefaultPolicy'] as String? ?? defaultMissedDayPolicy,
      latinDisplayEnabled: json['latinDisplayEnabled'] as bool? ?? true,
      luminousSetEnabled: json['luminousSetEnabled'] as bool? ?? true,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'baseSettings': baseSettings.toJson(),
      'angelusMorning': _timeToJson(angelusMorning),
      'angelusNoon': _timeToJson(angelusNoon),
      'angelusEvening': _timeToJson(angelusEvening),
      'mercyHour': _timeToJson(mercyHour),
      'morningReminderEnabled': morningReminderEnabled,
      'eveningReminderEnabled': eveningReminderEnabled,
      'nightItemsEnabled': nightItemsEnabled,
      'enableAngelusAnchors': enableAngelusAnchors,
      'enableMercyHourAnchor': enableMercyHourAnchor,
      'missedDayDefaultPolicy': missedDayDefaultPolicy,
      'latinDisplayEnabled': latinDisplayEnabled,
      'luminousSetEnabled': luminousSetEnabled,
      'onboardingComplete': onboardingComplete,
    };
  }

  /// Create a copy with updated values.
  DevotionsAppSettings copyWith({
    BaseSettingsModel? baseSettings,
    TimeOfDay? angelusMorning,
    TimeOfDay? angelusNoon,
    TimeOfDay? angelusEvening,
    TimeOfDay? mercyHour,
    bool? morningReminderEnabled,
    bool? eveningReminderEnabled,
    bool? nightItemsEnabled,
    bool? enableAngelusAnchors,
    bool? enableMercyHourAnchor,
    String? missedDayDefaultPolicy,
    bool? latinDisplayEnabled,
    bool? luminousSetEnabled,
    bool? onboardingComplete,
  }) {
    return DevotionsAppSettings(
      baseSettings: baseSettings ?? this.baseSettings,
      angelusMorning: angelusMorning ?? this.angelusMorning,
      angelusNoon: angelusNoon ?? this.angelusNoon,
      angelusEvening: angelusEvening ?? this.angelusEvening,
      mercyHour: mercyHour ?? this.mercyHour,
      morningReminderEnabled:
          morningReminderEnabled ?? this.morningReminderEnabled,
      eveningReminderEnabled:
          eveningReminderEnabled ?? this.eveningReminderEnabled,
      nightItemsEnabled: nightItemsEnabled ?? this.nightItemsEnabled,
      enableAngelusAnchors: enableAngelusAnchors ?? this.enableAngelusAnchors,
      enableMercyHourAnchor:
          enableMercyHourAnchor ?? this.enableMercyHourAnchor,
      missedDayDefaultPolicy:
          missedDayDefaultPolicy ?? this.missedDayDefaultPolicy,
      latinDisplayEnabled: latinDisplayEnabled ?? this.latinDisplayEnabled,
      luminousSetEnabled: luminousSetEnabled ?? this.luminousSetEnabled,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  /// Update base settings while preserving app-specific settings.
  DevotionsAppSettings updateBaseSettings(BaseSettingsModel newBaseSettings) {
    return copyWith(baseSettings: newBaseSettings);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DevotionsAppSettings &&
        other.baseSettings == baseSettings &&
        other.angelusMorning == angelusMorning &&
        other.angelusNoon == angelusNoon &&
        other.angelusEvening == angelusEvening &&
        other.mercyHour == mercyHour &&
        other.morningReminderEnabled == morningReminderEnabled &&
        other.eveningReminderEnabled == eveningReminderEnabled &&
        other.nightItemsEnabled == nightItemsEnabled &&
        other.enableAngelusAnchors == enableAngelusAnchors &&
        other.enableMercyHourAnchor == enableMercyHourAnchor &&
        other.missedDayDefaultPolicy == missedDayDefaultPolicy &&
        other.latinDisplayEnabled == latinDisplayEnabled &&
        other.luminousSetEnabled == luminousSetEnabled &&
        other.onboardingComplete == onboardingComplete;
  }

  @override
  int get hashCode {
    return Object.hash(
      baseSettings,
      angelusMorning,
      angelusNoon,
      angelusEvening,
      mercyHour,
      morningReminderEnabled,
      eveningReminderEnabled,
      nightItemsEnabled,
      enableAngelusAnchors,
      enableMercyHourAnchor,
      missedDayDefaultPolicy,
      latinDisplayEnabled,
      luminousSetEnabled,
      onboardingComplete,
    );
  }

  @override
  String toString() {
    return 'DevotionsAppSettings('
        'baseSettings: $baseSettings, '
        'angelusMorning: $angelusMorning, '
        'angelusNoon: $angelusNoon, '
        'angelusEvening: $angelusEvening, '
        'mercyHour: $mercyHour, '
        'morningReminderEnabled: $morningReminderEnabled, '
        'eveningReminderEnabled: $eveningReminderEnabled, '
        'nightItemsEnabled: $nightItemsEnabled, '
        'enableAngelusAnchors: $enableAngelusAnchors, '
        'enableMercyHourAnchor: $enableMercyHourAnchor, '
        'missedDayDefaultPolicy: $missedDayDefaultPolicy, '
        'latinDisplayEnabled: $latinDisplayEnabled, '
        'luminousSetEnabled: $luminousSetEnabled, '
        'onboardingComplete: $onboardingComplete'
        ')';
  }
}
