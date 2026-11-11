import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saint_app_settings.dart';
import '../utils/logger.dart';

/// Notifier for Saint app specific settings (favorites + recents),
/// persisted to SharedPreferences.
///
/// Load/write safety:
/// - The async load never clobbers a mutation that raced it. If [state] was
///   mutated before the stored settings arrive, they are merged and the
///   merged state is re-persisted. Merge rule: favorites = current first,
///   then loaded favorites not already present; recents = current first,
///   then loaded recents not already present, capped at
///   [SaintAppSettings.maxRecentSlugs].
/// - Disk writes are serialized through a single queue so they land in the
///   same order as the state mutations that produced them; each write
///   persists the latest state when it runs (last state wins on disk).
class SaintAppSettingsNotifier extends StateNotifier<SaintAppSettings> {
  static const String storageKey = 'saint_app_settings';

  /// Whether a mutation happened before the async load resolved.
  bool _mutationSinceLoad = false;

  /// Tail of the serialized persist chain.
  Future<void>? _persistQueue;

  SaintAppSettingsNotifier() : super(SaintAppSettings.defaults()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(storageKey);

      if (settingsJson != null) {
        final settingsMap = json.decode(settingsJson) as Map<String, dynamic>;
        final settings = SaintAppSettings.fromJson(settingsMap);

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
        state = SaintAppSettings.defaults();
      }
    } catch (e) {
      AppLogger.error('Failed to load saint settings', e, null, 'SETTINGS');
      // Continue with the current state (defaults unless a mutation raced the
      // load) — never crash the app on a bad settings store.
    }
  }

  /// Merge a racing mutation's [current] state with [loaded] settings so
  /// neither the user's in-session changes nor stored history is lost.
  static SaintAppSettings _mergeSettings(
    SaintAppSettings current,
    SaintAppSettings loaded,
  ) {
    final favorites = <String>[...current.favoriteSlugs];
    for (final slug in loaded.favoriteSlugs) {
      if (!favorites.contains(slug)) {
        favorites.add(slug);
      }
    }
    final recents = <String>[...current.recentSlugs];
    for (final slug in loaded.recentSlugs) {
      if (!recents.contains(slug)) {
        recents.add(slug);
      }
    }
    if (recents.length > SaintAppSettings.maxRecentSlugs) {
      recents.removeRange(SaintAppSettings.maxRecentSlugs, recents.length);
    }
    return SaintAppSettings(favoriteSlugs: favorites, recentSlugs: recents);
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
      AppLogger.error('Failed to save saint settings', e, null, 'SETTINGS');
    }
  }

  /// Add or remove a saint from favorites, persisting the change
  Future<void> toggleFavorite(String slug) async {
    _mutationSinceLoad = true;
    if (state.isFavorite(slug)) {
      state = state.removeFavorite(slug);
    } else {
      state = state.addFavorite(slug);
    }
    return _scheduleSave();
  }

  /// Record a saint as recently viewed (most-recent-first, dedupe, cap 50)
  Future<void> addRecent(String slug) async {
    _mutationSinceLoad = true;
    state = state.addToRecent(slug);
    return _scheduleSave();
  }

  /// Whether a saint is favorited
  bool isFavorite(String slug) => state.isFavorite(slug);
}

/// Provider for Saint app settings
final saintAppSettingsProvider =
    StateNotifierProvider<SaintAppSettingsNotifier, SaintAppSettings>((ref) {
      return SaintAppSettingsNotifier();
    });
