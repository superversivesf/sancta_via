import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_state.dart';
import '../models/mystery_set.dart';
import '../models/prayer_type.dart';
import '../services/audio_service.dart';
import 'settings_provider.dart';
import 'rosary_session_provider.dart';

/// Provider for the audio service instance
/// Initializes with settings from RosaryAppSettingsProvider
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService.instance;

  // Initialize the service when the provider is first created
  service.initialize();

  // Listen to settings changes and update audio service
  ref.listen(rosaryAppSettingsProvider, (previous, next) {
    if (previous != null) {
      service.updateSettings(
        volume: next.audioVolume,
        autoPlayEnabled: next.autoPlayPrayers && next.audioEnabled,
        autoAdvanceEnabled: true, // Auto-advance is handled separately
      );
    } else {
      // Initial settings sync
      service.updateSettings(
        volume: next.audioVolume,
        autoPlayEnabled: next.autoPlayPrayers && next.audioEnabled,
        autoAdvanceEnabled: true,
      );
    }
  });

  // Set initial settings
  final settings = ref.read(rosaryAppSettingsProvider);
  service.updateSettings(
    volume: settings.audioVolume,
    autoPlayEnabled: settings.autoPlayPrayers && settings.audioEnabled,
    autoAdvanceEnabled: true,
  );

  // Dispose when the provider is destroyed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Stream provider for audio state updates
final audioStateStreamProvider = StreamProvider<AudioState>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.stateStream;
});

/// Provider for the current audio state
final audioStateProvider = Provider<AudioState>((ref) {
  final asyncValue = ref.watch(audioStateStreamProvider);
  return asyncValue.when(
    data: (state) => state,
    loading: () => const AudioState(),
    error: (_, __) => const AudioState(errorMessage: 'Audio error'),
  );
});

/// Provider for whether audio is currently playing
final isPlayingProvider = Provider<bool>((ref) {
  final state = ref.watch(audioStateProvider);
  return state.isPlaying;
});

/// Provider for current audio progress (0.0 to 1.0)
final audioProgressProvider = Provider<double>((ref) {
  final state = ref.watch(audioStateProvider);
  return state.progress;
});

/// Provider for formatted current position
final audioPositionProvider = Provider<String>((ref) {
  final state = ref.watch(audioStateProvider);
  return state.formattedPosition;
});

/// Provider for formatted total duration
final audioDurationProvider = Provider<String>((ref) {
  final state = ref.watch(audioStateProvider);
  return state.formattedDuration;
});

/// Provider for whether auto-advance is enabled
/// Uses rosaryAutoPlayPrayersProvider from settings_provider for persistence
final autoAdvanceProvider = StateNotifierProvider<AutoAdvanceNotifier, bool>(
  (ref) => AutoAdvanceNotifier(ref),
);

/// Notifier for managing auto-advance setting
/// Syncs with RosaryAppSettingsProvider for persistence
class AutoAdvanceNotifier extends StateNotifier<bool> {
  final Ref _ref;
  bool _initialized = false;

  AutoAdvanceNotifier(this._ref) : super(true) {
    // Listen to settings provider and sync state
    _ref.listen(rosaryAutoPlayPrayersProvider, (previous, next) {
      if (!_initialized || state != next) {
        state = next;
        _initialized = true;
      }
    });

    // Initialize from current settings
    final settings = _ref.read(rosaryAppSettingsProvider);
    state = settings.autoPlayPrayers;
    _initialized = true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    // Also update the audio service
    AudioService.instance.setAutoAdvance(enabled);
    // Persist to settings using the proper method
    await _ref
        .read(rosaryAppSettingsProvider.notifier)
        .setAutoPlayPrayers(enabled);
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

/// Provider for the audio player controller
///
/// This provides methods to control audio playback
final audioControllerProvider = Provider<AudioController>((ref) {
  final service = ref.watch(audioServiceProvider);
  return AudioController(service: service, ref: ref);
});

/// Controller class for managing audio playback operations
///
/// Provides high-level methods for playing prayers and mysteries,
/// handling the completion callbacks and auto-advance logic.
class AudioController {
  final AudioService _service;
  final Ref _ref;

  AudioController({required AudioService service, required Ref ref})
    : _service = service,
      _ref = ref;

  /// Play a prayer audio
  ///
  /// [prayerType] determines which prayer to play
  /// [onComplete] optional callback when playback completes
  Future<bool> playPrayer(
    PrayerType prayerType, {
    VoidCallback? onComplete,
  }) async {
    _setCompletionCallback(onComplete);
    return _service.playPrayer(prayerType);
  }

  /// Play a mystery description audio
  ///
  /// [mysteryNumber] is 1-5 for the mystery in the set
  /// [mysterySet] is the mystery set (e.g., MysterySet.joyful)
  /// [onComplete] optional callback when playback completes
  Future<bool> playMysteryDescription(
    int mysteryNumber,
    MysterySet mysterySet, {
    VoidCallback? onComplete,
  }) async {
    _setCompletionCallback(onComplete);
    final setName = _getMysterySetName(mysterySet);
    return _service.playMysteryDescription(mysteryNumber, setName);
  }

  /// Auto-play the appropriate audio for the current rosary state
  ///
  /// This should be called when the prayer step changes
  /// [prayerType] is the specific prayer type to play (for opening prayers)
  Future<void> autoPlayForStep({
    required PrayerStep prayerStep,
    required int mysteryNumber,
    required MysterySet mysterySet,
    PrayerType? prayerType,
    VoidCallback? onComplete,
  }) async {
    // Only auto-play if auto-advance is enabled
    final autoAdvance = _ref.read(autoAdvanceProvider);
    if (!autoAdvance) return;

    switch (prayerStep) {
      case PrayerStep.opening:
        // Play specific opening prayer (Sign of Cross, Apostles Creed, etc.)
        if (prayerType != null) {
          await playPrayer(prayerType, onComplete: onComplete);
        }
        break;
      case PrayerStep.announceMystery:
        // Play mystery description
        await playMysteryDescription(
          mysteryNumber,
          mysterySet,
          onComplete: onComplete,
        );
        break;
      case PrayerStep.ourFather:
        await playPrayer(PrayerType.ourFather, onComplete: onComplete);
        break;
      case PrayerStep.hailMary:
        await playPrayer(PrayerType.hailMary, onComplete: onComplete);
        break;
      case PrayerStep.gloryBe:
        await playPrayer(PrayerType.gloryBe, onComplete: onComplete);
        break;
      case PrayerStep.fatima:
        await playPrayer(PrayerType.fatimaPrayer, onComplete: onComplete);
        break;
      case PrayerStep.closing:
        await playPrayer(PrayerType.closing, onComplete: onComplete);
        break;
      case PrayerStep.complete:
        // No audio for completion
        break;
    }
  }

  /// Play mystery description for the current decade
  ///
  /// This is called when starting a new decade
  Future<bool> playCurrentMysteryDescription(
    int mysteryNumber,
    MysterySet mysterySet, {
    VoidCallback? onComplete,
  }) {
    return playMysteryDescription(
      mysteryNumber,
      mysterySet,
      onComplete: onComplete,
    );
  }

  /// Pause current playback
  Future<void> pause() => _service.pause();

  /// Resume paused playback
  Future<void> resume() => _service.resume();

  /// Stop playback
  Future<void> stop() => _service.stop();

  /// Toggle between play and pause
  Future<void> togglePlayPause() => _service.togglePlayPause();

  /// Seek to a specific position
  Future<void> seekTo(Duration position) => _service.seekTo(position);

  /// Check if audio is currently playing
  bool get isPlaying => _service.currentState.isPlaying;

  /// Check if audio is currently paused
  bool get isPaused => _service.currentState.isPaused;

  /// Get current audio state
  AudioState get currentState => _service.currentState;

  /// Set completion callback
  void _setCompletionCallback(VoidCallback? callback) {
    if (callback != null) {
      _service.setOnCompleteCallback(callback);
    } else {
      _service.clearOnCompleteCallback();
    }
  }

  /// Get the string name for a mystery set
  String _getMysterySetName(MysterySet set) {
    switch (set) {
      case MysterySet.joyful:
        return 'joyful';
      case MysterySet.sorrowful:
        return 'sorrowful';
      case MysterySet.glorious:
        return 'glorious';
      case MysterySet.luminous:
        return 'luminous';
    }
  }
}

/// Provider for whether audio controls should be visible
/// Controls are visible when there is loaded audio
final audioControlsVisibleProvider = Provider<bool>((ref) {
  final state = ref.watch(audioStateProvider);
  return state.hasAudio;
});

/// Provider for the current audio display name
final audioDisplayNameProvider = Provider<String>((ref) {
  final state = ref.watch(audioStateProvider);
  return state.displayName;
});

/// Extension on PrayerType to get display name
extension PrayerTypeExtension on PrayerType {
  String get displayName {
    switch (this) {
      case PrayerType.signOfCross:
        return 'Sign of the Cross';
      case PrayerType.apostlesCreed:
        return 'Apostles\' Creed';
      case PrayerType.openingOurFather:
        return 'Our Father';
      case PrayerType.openingHailMary:
        return 'Hail Mary';
      case PrayerType.mystery:
        return 'Mystery';
      case PrayerType.ourFather:
        return 'Our Father';
      case PrayerType.hailMary:
        return 'Hail Mary';
      case PrayerType.gloryBe:
        return 'Glory Be';
      case PrayerType.fatimaPrayer:
        return 'Fatima Prayer';
      case PrayerType.closing:
        return 'Closing';
    }
  }
}
