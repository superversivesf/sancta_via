import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// The four daily anchor times, named per their [DevotionsAppSettings] fields.
typedef AnchorTimes = ({
  TimeOfDay angelusMorning,
  TimeOfDay angelusNoon,
  TimeOfDay angelusEvening,
  TimeOfDay mercyHour,
});

/// Notifier for Devotionals app settings (anchor times, reminders, display
/// preferences, onboarding), persisted to SharedPreferences under a single
/// JSON blob.
///
/// Load/write safety (house pattern from the saint-companion settings work):
/// - The async load never clobbers a mutation that raced it. If [state] was
///   already mutated when the stored settings arrive, the two are merged and
///   the merged state is re-persisted. Scalar merge rule, per field: values
///   the in-session mutation already moved off their default stay (current
///   wins); every other field takes the stored value when the store
///   customized it, or the default otherwise. [DevotionsAppSettings.baseSettings]
///   follows the same rule against [BaseSettingsModel.defaults].
/// - Disk writes are serialized through a single queue so they land in the
///   same order as the state mutations that produced them; each write
///   persists the latest state when it runs (last state wins on disk).
/// - Corrupt or missing stored JSON keeps the current state (constructor
///   defaults unless a mutation raced the load) — never crashes.
///
/// Base-setting sync is one-way: the shared [baseSettingsProvider] is
/// authoritative. When it changes, the app's [DevotionsAppSettings.baseSettings]
/// is replaced (and persisted as a snapshot); the app never pushes its own
/// snapshot back into the shared provider.
class DevotionsSettingsNotifier extends StateNotifier<DevotionsAppSettings> {
  static const String storageKey = 'devotionals_app_settings';

  final Ref _ref;

  /// Whether a mutation happened before the async load resolved.
  bool _mutationSinceLoad = false;

  /// Tail of the serialized persist chain.
  Future<void>? _persistQueue;

  DevotionsSettingsNotifier(this._ref)
    : super(DevotionsAppSettings.defaults()) {
    _loadSettings();

    // Listen to base settings changes and sync them into the app state.
    _ref.listen(baseSettingsProvider, (previous, next) {
      if (previous != next) {
        _syncBaseSettings(next);
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(storageKey);

      if (settingsJson != null) {
        final settingsMap = json.decode(settingsJson) as Map<String, dynamic>;
        final settings = DevotionsAppSettings.fromJson(settingsMap);

        if (mounted) {
          if (_mutationSinceLoad) {
            // A mutation raced the load: merge instead of clobbering, and
            // re-persist the merged state so disk keeps the union.
            state = _mergeSettings(state, settings);
            await _scheduleSave();
          } else {
            state = settings;
          }
        }
      } else if (!_mutationSinceLoad && mounted) {
        // Nothing stored yet: fall back to defaults unless a mutation raced
        // the load, which would otherwise be clobbered.
        state = DevotionsAppSettings.defaults();
      }
    } catch (e) {
      // Corrupt or unreadable store: continue with the current state —
      // never crash the app on a bad settings store.
    }
  }

  /// Merge a racing mutation's [current] state with [loaded] stored settings
  /// so neither the user's in-session changes nor stored customizations are
  /// lost. Per field: current wins when it has already moved off its default;
  /// otherwise the stored value wins when the store customized it.
  static DevotionsAppSettings _mergeSettings(
    DevotionsAppSettings current,
    DevotionsAppSettings loaded,
  ) {
    final defaults = DevotionsAppSettings.defaults();

    bool pick(bool currentValue, bool loadedValue, bool defaultValue) {
      return currentValue != defaultValue ? currentValue : loadedValue;
    }

    return DevotionsAppSettings(
      baseSettings: current.baseSettings != defaults.baseSettings
          ? current.baseSettings
          : loaded.baseSettings,
      angelusMorning: current.angelusMorning != defaults.angelusMorning
          ? current.angelusMorning
          : loaded.angelusMorning,
      angelusNoon: current.angelusNoon != defaults.angelusNoon
          ? current.angelusNoon
          : loaded.angelusNoon,
      angelusEvening: current.angelusEvening != defaults.angelusEvening
          ? current.angelusEvening
          : loaded.angelusEvening,
      mercyHour: current.mercyHour != defaults.mercyHour
          ? current.mercyHour
          : loaded.mercyHour,
      morningReminderEnabled: pick(
        current.morningReminderEnabled,
        loaded.morningReminderEnabled,
        defaults.morningReminderEnabled,
      ),
      eveningReminderEnabled: pick(
        current.eveningReminderEnabled,
        loaded.eveningReminderEnabled,
        defaults.eveningReminderEnabled,
      ),
      nightItemsEnabled: pick(
        current.nightItemsEnabled,
        loaded.nightItemsEnabled,
        defaults.nightItemsEnabled,
      ),
      enableAngelusAnchors: pick(
        current.enableAngelusAnchors,
        loaded.enableAngelusAnchors,
        defaults.enableAngelusAnchors,
      ),
      enableMercyHourAnchor: pick(
        current.enableMercyHourAnchor,
        loaded.enableMercyHourAnchor,
        defaults.enableMercyHourAnchor,
      ),
      missedDayDefaultPolicy:
          current.missedDayDefaultPolicy != defaults.missedDayDefaultPolicy
          ? current.missedDayDefaultPolicy
          : loaded.missedDayDefaultPolicy,
      latinDisplayEnabled: pick(
        current.latinDisplayEnabled,
        loaded.latinDisplayEnabled,
        defaults.latinDisplayEnabled,
      ),
      luminousSetEnabled: pick(
        current.luminousSetEnabled,
        loaded.luminousSetEnabled,
        defaults.luminousSetEnabled,
      ),
      onboardingComplete: pick(
        current.onboardingComplete,
        loaded.onboardingComplete,
        defaults.onboardingComplete,
      ),
    );
  }

  /// Enqueue a sequential disk write of the latest state: writes land in the
  /// same order as the mutations that requested them (last state wins).
  Future<void> _scheduleSave() {
    final preceding = _persistQueue ?? Future<void>.value();
    final write = preceding.then((_) => _saveSettings());
    _persistQueue = write;
    return write;
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, json.encode(state.toJson()));
    } catch (e) {
      // Keep settings in memory even if the disk write fails.
    }
  }

  void _syncBaseSettings(BaseSettingsModel newBase) {
    if (state.baseSettings == newBase) {
      return;
    }
    _mutationSinceLoad = true;
    state = state.updateBaseSettings(newBase);
    _scheduleSave();
  }

  /// Apply one app-field mutation and persist it.
  Future<void> _mutate(DevotionsAppSettings next) {
    _mutationSinceLoad = true;
    state = next;
    return _scheduleSave();
  }

  Future<void> setAngelusMorning(TimeOfDay time) =>
      _mutate(state.copyWith(angelusMorning: time));

  Future<void> setAngelusNoon(TimeOfDay time) =>
      _mutate(state.copyWith(angelusNoon: time));

  Future<void> setAngelusEvening(TimeOfDay time) =>
      _mutate(state.copyWith(angelusEvening: time));

  Future<void> setMercyHour(TimeOfDay time) =>
      _mutate(state.copyWith(mercyHour: time));

  Future<void> setMorningReminderEnabled(bool enabled) =>
      _mutate(state.copyWith(morningReminderEnabled: enabled));

  Future<void> setEveningReminderEnabled(bool enabled) =>
      _mutate(state.copyWith(eveningReminderEnabled: enabled));

  Future<void> setNightItemsEnabled(bool enabled) =>
      _mutate(state.copyWith(nightItemsEnabled: enabled));

  Future<void> setAngelusAnchorsEnabled(bool enabled) =>
      _mutate(state.copyWith(enableAngelusAnchors: enabled));

  Future<void> setMercyHourAnchorEnabled(bool enabled) =>
      _mutate(state.copyWith(enableMercyHourAnchor: enabled));

  Future<void> setMissedDayDefaultPolicy(String policy) =>
      _mutate(state.copyWith(missedDayDefaultPolicy: policy));

  Future<void> setLatinDisplayEnabled(bool enabled) =>
      _mutate(state.copyWith(latinDisplayEnabled: enabled));

  Future<void> setLuminousSetEnabled(bool enabled) =>
      _mutate(state.copyWith(luminousSetEnabled: enabled));

  Future<void> setOnboardingComplete(bool complete) =>
      _mutate(state.copyWith(onboardingComplete: complete));
}

/// Provider for Devotionals app settings.
final devotionsSettingsProvider =
    StateNotifierProvider<DevotionsSettingsNotifier, DevotionsAppSettings>((
      ref,
    ) {
      return DevotionsSettingsNotifier(ref);
    });

/// Convenience providers for the settings downstream tasks consume directly.
final anchorTimesProvider = Provider<AnchorTimes>((ref) {
  final settings = ref.watch(devotionsSettingsProvider);
  return (
    angelusMorning: settings.angelusMorning,
    angelusNoon: settings.angelusNoon,
    angelusEvening: settings.angelusEvening,
    mercyHour: settings.mercyHour,
  );
});

final missedDayDefaultPolicyProvider = Provider<String>((ref) {
  return ref.watch(devotionsSettingsProvider).missedDayDefaultPolicy;
});

final latinDisplayProvider = Provider<bool>((ref) {
  return ref.watch(devotionsSettingsProvider).latinDisplayEnabled;
});

final onboardingCompleteProvider = Provider<bool>((ref) {
  return ref.watch(devotionsSettingsProvider).onboardingComplete;
});
