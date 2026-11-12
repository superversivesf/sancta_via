import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sancta_via_devotionals/models/app_settings.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

void main() {
  group('DevotionsAppSettings defaults', () {
    test('anchor times are 6:00, 12:00, 18:00 and the mercy hour is 15:00', () {
      final settings = DevotionsAppSettings.defaults();
      expect(settings.angelusMorning, const TimeOfDay(hour: 6, minute: 0));
      expect(settings.angelusNoon, const TimeOfDay(hour: 12, minute: 0));
      expect(settings.angelusEvening, const TimeOfDay(hour: 18, minute: 0));
      expect(settings.mercyHour, const TimeOfDay(hour: 15, minute: 0));
    });

    test('toggles and policy carry their pinned defaults', () {
      final settings = DevotionsAppSettings.defaults();
      expect(settings.missedDayDefaultPolicy, 'permissive');
      expect(settings.baseSettings, BaseSettingsModel.defaults());

      // Reminder and night features start off.
      expect(settings.morningReminderEnabled, isFalse);
      expect(settings.eveningReminderEnabled, isFalse);
      expect(settings.nightItemsEnabled, isFalse);

      // Display/anchor enrichments start on.
      expect(settings.enableAngelusAnchors, isTrue);
      expect(settings.enableMercyHourAnchor, isTrue);
      expect(settings.latinDisplayEnabled, isTrue);
      expect(settings.luminousSetEnabled, isTrue);

      expect(settings.onboardingComplete, isFalse);
    });
  });

  group('DevotionsAppSettings serialization', () {
    test('toJson/fromJson round-trips every field', () {
      final original = DevotionsAppSettings.defaults().copyWith(
        baseSettings: BaseSettingsModel.defaults().copyWith(fontSize: 22),
        angelusMorning: const TimeOfDay(hour: 7, minute: 30),
        angelusNoon: const TimeOfDay(hour: 12, minute: 15),
        angelusEvening: const TimeOfDay(hour: 20, minute: 45),
        mercyHour: const TimeOfDay(hour: 17, minute: 5),
        morningReminderEnabled: true,
        eveningReminderEnabled: true,
        nightItemsEnabled: true,
        enableAngelusAnchors: false,
        enableMercyHourAnchor: false,
        missedDayDefaultPolicy: 'strict',
        latinDisplayEnabled: false,
        luminousSetEnabled: false,
        onboardingComplete: true,
      );

      final restored = DevotionsAppSettings.fromJson(original.toJson());

      expect(restored, original);
      expect(restored.angelusMorning, const TimeOfDay(hour: 7, minute: 30));
      expect(restored.mercyHour, const TimeOfDay(hour: 17, minute: 5));
      expect(restored.missedDayDefaultPolicy, 'strict');
      expect(restored.onboardingComplete, isTrue);
      expect(restored.baseSettings.fontSize, 22);
    });

    test('TimeOfDay fields serialize as hour/minute maps', () {
      final json = DevotionsAppSettings.defaults().toJson();
      expect(json['angelusMorning'], <String, dynamic>{'hour': 6, 'minute': 0});
      expect(json['angelusNoon'], <String, dynamic>{'hour': 12, 'minute': 0});
      expect(json['angelusEvening'], <String, dynamic>{
        'hour': 18,
        'minute': 0,
      });
      expect(json['mercyHour'], <String, dynamic>{'hour': 15, 'minute': 0});
    });

    test('fromJson falls back to defaults for missing fields', () {
      final settings = DevotionsAppSettings.fromJson(const <String, dynamic>{});
      expect(settings, DevotionsAppSettings.defaults());
    });

    test('fromJson clamps malformed times and falls back for bad shapes', () {
      final settings = DevotionsAppSettings.fromJson(const <String, dynamic>{
        'angelusMorning': <String, dynamic>{'hour': 25, 'minute': 700},
        'mercyHour': 'garbage',
        'latinDisplayEnabled': false,
      });
      expect(settings.angelusMorning, const TimeOfDay(hour: 23, minute: 59));
      expect(settings.mercyHour, const TimeOfDay(hour: 15, minute: 0));
      expect(settings.latinDisplayEnabled, isFalse);
    });
  });

  group('DevotionsAppSettings copyWith', () {
    test('replaces single fields and leaves the rest untouched', () {
      final defaults = DevotionsAppSettings.defaults();
      final changed = defaults.copyWith(nightItemsEnabled: true);
      expect(changed.nightItemsEnabled, isTrue);
      expect(changed.missedDayDefaultPolicy, defaults.missedDayDefaultPolicy);
      expect(changed.angelusMorning, defaults.angelusMorning);
      expect(defaults.nightItemsEnabled, isFalse);
    });

    test('replaces base settings while keeping app fields', () {
      final updatedBase = BaseSettingsModel.defaults().copyWith(
        notificationsEnabled: true,
      );
      final changed = DevotionsAppSettings.defaults().copyWith(
        baseSettings: updatedBase,
      );
      expect(changed.baseSettings.notificationsEnabled, isTrue);
      expect(changed.luminousSetEnabled, isTrue);
      expect(
        changed,
        DevotionsAppSettings.defaults().updateBaseSettings(updatedBase),
      );
    });
  });
}
