import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/audio_state.dart';
import '../models/prayer_type.dart';
import '../utils/logger.dart';

/// Service for managing audio playback in the rosary app
///
/// Handles playing prayers, mystery descriptions, and managing playback state.
/// Uses just_audio package for reliable audio playback.
///
/// Settings (volume, auto-play, auto-advance) are injected from RosaryAppSettingsProvider
/// via the AudioController in audio_provider.dart
class AudioService {
  static final AudioService _instance = AudioService._internal();
  static AudioService get instance => _instance;

  // The audio player from just_audio
  late final AudioPlayer _player;

  // Audio session for managing audio focus
  AudioSession? _session;

  // Stream controller for state updates
  final _stateController = StreamController<AudioState>.broadcast();

  // Current state
  AudioState _currentState = const AudioState();

  // Completion callback
  VoidCallback? _onCompleteCallback;

  // Timer for position updates
  Timer? _positionTimer;

  // Whether the service is initialized
  bool _isInitialized = false;

  // Settings - can be updated from outside via updateSettings()
  double _volume = 1.0;
  bool _autoPlayEnabled = true;
  bool _autoAdvanceEnabled = true;

  AudioService._internal();

  /// Stream of audio state updates
  Stream<AudioState> get stateStream => _stateController.stream;

  /// Current audio state
  AudioState get currentState => _currentState;

  /// Current volume level (0.0 to 1.0)
  double get volume => _volume;

  /// Whether auto-play is enabled
  bool get autoPlayEnabled => _autoPlayEnabled;

  /// Whether auto-advance is enabled
  bool get autoAdvanceEnabled => _autoAdvanceEnabled;

  /// Update audio settings from RosaryAppSettings
  void updateSettings({
    double? volume,
    bool? autoPlayEnabled,
    bool? autoAdvanceEnabled,
  }) {
    if (volume != null) {
      _volume = volume.clamp(0.0, 1.0);
      _player.setVolume(_volume);
    }
    if (autoPlayEnabled != null) {
      _autoPlayEnabled = autoPlayEnabled;
    }
    if (autoAdvanceEnabled != null) {
      _autoAdvanceEnabled = autoAdvanceEnabled;
      _currentState = _currentState.copyWith(
        autoAdvanceEnabled: _autoAdvanceEnabled,
      );
      _stateController.add(_currentState);
    }
  }

  /// Initialize the audio service
  /// Must be called before using any other methods
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Create the audio player
      _player = AudioPlayer();

      // Configure audio session
      _session = await AudioSession.instance;
      await _session!.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
        ),
      );

      // Listen to player state changes
      _player.playerStateStream.listen(_handlePlayerStateChange);

      // Listen to duration changes
      _player.durationStream.listen(_handleDurationChange);

      // Start position update timer
      _startPositionTimer();

      _isInitialized = true;

      // Emit initial state so widgets can react immediately
      _stateController.add(_currentState);

      AppLogger.info('AudioService initialized', 'AUDIO');
    } catch (e) {
      AppLogger.error('Failed to initialize AudioService', e, null, 'AUDIO');
      _currentState = _currentState.copyWith(
        errorMessage: 'Failed to initialize audio: $e',
      );
      _stateController.add(_currentState);
    }
  }

  /// Dispose the audio service and release resources
  Future<void> dispose() async {
    _positionTimer?.cancel();
    await _player.dispose();
    await _stateController.close();
    _isInitialized = false;
  }

  /// Play a prayer audio file
  ///
  /// [prayerType] determines which prayer audio to play
  /// Returns true if playback started successfully
  ///
  /// Note: If audioEnabled is false from settings, this returns false immediately.
  /// The caller should check audioEnabled from rosaryAppSettingsProvider first.
  Future<bool> playPrayer(PrayerType prayerType) async {
    if (!_isInitialized) {
      await initialize();
    }

    // If auto-play is disabled, don't play
    if (!_autoPlayEnabled) {
      AppLogger.debug('Auto-play disabled, skipping prayer audio', 'AUDIO');
      return false;
    }

    try {
      final audioPath = _getPrayerAudioPath(prayerType);
      if (audioPath == null) {
        AppLogger.warning('No audio path for prayer: $prayerType', 'AUDIO');
        return false;
      }

      // Stop any current playback
      await stop();

      // Update state to loading
      _currentState = _currentState.copyWith(
        currentAudioType: AudioType.prayer,
        currentPrayerType: prayerType,
        isPlaying: false,
        isPaused: false,
        isCompleted: false,
        clearError: true,
      );
      _stateController.add(_currentState);

      // Set the audio source
      await _player.setAsset(audioPath);

      // Apply current volume setting
      await _player.setVolume(_volume);

      // Start playback
      await _player.play();

      // Activate audio session
      await _session?.setActive(true);

      AppLogger.info('Playing prayer: $prayerType (volume: $_volume)', 'AUDIO');
      return true;
    } catch (e) {
      AppLogger.error('Failed to play prayer', e, null, 'AUDIO');
      _currentState = _currentState.copyWith(
        errorMessage: 'Failed to play audio: $e',
      );
      _stateController.add(_currentState);
      return false;
    }
  }

  /// Play a mystery description audio file
  ///
  /// [mysteryNumber] is 1-5 for the mystery in the set
  /// [mysterySet] is the name of the mystery set (e.g., 'joyful', 'sorrowful')
  /// Returns true if playback started successfully
  ///
  /// Note: If audioEnabled is false from settings, this returns false immediately.
  Future<bool> playMysteryDescription(
    int mysteryNumber,
    String mysterySet,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    // If auto-play is disabled, don't play
    if (!_autoPlayEnabled) {
      AppLogger.debug('Auto-play disabled, skipping mystery audio', 'AUDIO');
      return false;
    }

    try {
      final audioPath = _getMysteryAudioPath(mysteryNumber, mysterySet);
      if (audioPath == null) {
        AppLogger.warning(
          'No audio path for mystery: $mysterySet-$mysteryNumber',
          'AUDIO',
        );
        return false;
      }

      // Stop any current playback
      await stop();

      // Update state to loading
      _currentState = _currentState.copyWith(
        currentAudioType: AudioType.mystery,
        currentMysteryId: '${mysterySet}_$mysteryNumber',
        isPlaying: false,
        isPaused: false,
        isCompleted: false,
        clearError: true,
        clearPrayerType: true,
      );
      _stateController.add(_currentState);

      // Set the audio source
      await _player.setAsset(audioPath);

      // Apply current volume setting
      await _player.setVolume(_volume);

      // Start playback
      await _player.play();

      // Activate audio session
      await _session?.setActive(true);

      AppLogger.info(
        'Playing mystery: $mysterySet-$mysteryNumber (volume: $_volume)',
        'AUDIO',
      );
      return true;
    } catch (e) {
      AppLogger.error('Failed to play mystery', e, null, 'AUDIO');
      _currentState = _currentState.copyWith(
        errorMessage: 'Failed to play audio: $e',
      );
      _stateController.add(_currentState);
      return false;
    }
  }

  /// Pause the current playback
  Future<void> pause() async {
    if (!_isInitialized) return;

    try {
      await _player.pause();
      _currentState = _currentState.copyWith(isPlaying: false, isPaused: true);
      _stateController.add(_currentState);
      AppLogger.debug('Audio paused', 'AUDIO');
    } catch (e) {
      AppLogger.error('Failed to pause audio', e, null, 'AUDIO');
    }
  }

  /// Resume paused playback
  Future<void> resume() async {
    if (!_isInitialized) return;

    try {
      await _player.play();
      _currentState = _currentState.copyWith(isPlaying: true, isPaused: false);
      _stateController.add(_currentState);
      AppLogger.debug('Audio resumed', 'AUDIO');
    } catch (e) {
      AppLogger.error('Failed to resume audio', e, null, 'AUDIO');
    }
  }

  /// Stop playback and reset position
  Future<void> stop() async {
    if (!_isInitialized) return;

    try {
      await _player.stop();
      await _player.seek(Duration.zero);

      _currentState = _currentState.copyWith(
        isPlaying: false,
        isPaused: false,
        isCompleted: false,
        currentPosition: Duration.zero,
      );
      _stateController.add(_currentState);

      // Deactivate audio session
      await _session?.setActive(false);

      AppLogger.debug('Audio stopped', 'AUDIO');
    } catch (e) {
      AppLogger.error('Failed to stop audio', e, null, 'AUDIO');
    }
  }

  /// Seek to a specific position
  ///
  /// [position] is the position to seek to
  Future<void> seekTo(Duration position) async {
    if (!_isInitialized) return;

    try {
      await _player.seek(position);
      _currentState = _currentState.copyWith(currentPosition: position);
      _stateController.add(_currentState);
    } catch (e) {
      AppLogger.error('Failed to seek audio', e, null, 'AUDIO');
    }
  }

  /// Toggle between play and pause
  Future<void> togglePlayPause() async {
    if (_currentState.isPlaying) {
      await pause();
    } else if (_currentState.isPaused) {
      await resume();
    } else if (_currentState.hasAudio) {
      // Audio is loaded but stopped - just resume playback without stopping first
      try {
        await _player.play();
        _currentState = _currentState.copyWith(
          isPlaying: true,
          isPaused: false,
        );
        _stateController.add(_currentState);
        await _session?.setActive(true);
        AppLogger.debug('Audio resumed from stopped state', 'AUDIO');
      } catch (e) {
        AppLogger.error(
          'Failed to resume audio from stopped state',
          e,
          null,
          'AUDIO',
        );
        // Fallback: try to reload and play
        if (_currentState.currentAudioType == AudioType.prayer &&
            _currentState.currentPrayerType != null) {
          await playPrayer(_currentState.currentPrayerType!);
        } else if (_currentState.currentAudioType == AudioType.mystery &&
            _currentState.currentMysteryId != null) {
          final parts = _currentState.currentMysteryId!.split('_');
          if (parts.length == 2) {
            await playMysteryDescription(int.parse(parts[1]), parts[0]);
          }
        }
      }
    } else {
      // No audio loaded - this is an error state
      AppLogger.warning(
        'togglePlayPause called but no audio is loaded',
        'AUDIO',
      );
      _currentState = _currentState.copyWith(
        errorMessage: 'No audio loaded. Please select a prayer to play.',
      );
      _stateController.add(_currentState);
    }
  }

  /// Set the completion callback
  /// Called when audio playback completes naturally
  void setOnCompleteCallback(VoidCallback callback) {
    _onCompleteCallback = callback;
  }

  /// Clear the completion callback
  void clearOnCompleteCallback() {
    _onCompleteCallback = null;
  }

  /// Set auto-advance setting
  /// This is called from AudioController when settings change
  void setAutoAdvance(bool enabled) {
    _autoAdvanceEnabled = enabled;
    _currentState = _currentState.copyWith(autoAdvanceEnabled: enabled);
    _stateController.add(_currentState);
  }

  /// Get the audio path for a prayer type
  String? _getPrayerAudioPath(PrayerType type) {
    switch (type) {
      case PrayerType.signOfCross:
        return 'assets/audio/prayers/sign_of_cross.wav';
      case PrayerType.apostlesCreed:
        return 'assets/audio/prayers/apostles_creed.wav';
      case PrayerType.openingOurFather:
        return 'assets/audio/prayers/our_father.wav';
      case PrayerType.openingHailMary:
        return 'assets/audio/prayers/hail_mary.wav';
      case PrayerType.ourFather:
        return 'assets/audio/prayers/our_father.wav';
      case PrayerType.hailMary:
        return 'assets/audio/prayers/hail_mary.wav';
      case PrayerType.gloryBe:
        return 'assets/audio/prayers/glory_be.wav';
      case PrayerType.fatimaPrayer:
        return 'assets/audio/prayers/fatima_prayer.wav';
      case PrayerType.closing:
        return 'assets/audio/prayers/hail_holy_queen.wav';
      case PrayerType.mystery:
        // Mysteries have their own audio files
        return null;
    }
  }

  /// Get the audio path for a mystery
  String? _getMysteryAudioPath(int mysteryNumber, String mysterySet) {
    // Normalize the mystery set name
    final setName = mysterySet.toLowerCase().replaceAll(' ', '_');
    return 'assets/audio/mysteries/${setName}_$mysteryNumber.wav';
  }

  /// Handle player state changes
  void _handlePlayerStateChange(PlayerState state) {
    final isPlaying = state.playing;
    final processingState = state.processingState;

    // Update playing state
    if (isPlaying != _currentState.isPlaying) {
      _currentState = _currentState.copyWith(
        isPlaying: isPlaying,
        isPaused: !isPlaying && _currentState.hasAudio,
      );
    }

    // Handle completion
    if (processingState == ProcessingState.completed) {
      _currentState = _currentState.copyWith(
        isPlaying: false,
        isPaused: false,
        isCompleted: true,
        currentPosition: _currentState.totalDuration,
      );

      // Call completion callback if set
      if (_onCompleteCallback != null) {
        _onCompleteCallback!();
      }

      // Deactivate audio session
      _session?.setActive(false);
    }

    _stateController.add(_currentState);
  }

  /// Handle duration changes
  void _handleDurationChange(Duration? duration) {
    if (duration != null) {
      _currentState = _currentState.copyWith(totalDuration: duration);
      _stateController.add(_currentState);
    }
  }

  /// Start the position update timer
  void _startPositionTimer() {
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _updatePosition(),
    );
  }

  /// Update the current position
  void _updatePosition() {
    if (!_isInitialized) return;

    final position = _player.position;
    if (position != _currentState.currentPosition) {
      _currentState = _currentState.copyWith(currentPosition: position);
      _stateController.add(_currentState);
    }
  }
}
