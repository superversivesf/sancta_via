import 'package:flutter/foundation.dart';

import 'prayer_type.dart';

/// Represents the current state of audio playback in the rosary app
///
/// Tracks what is currently playing, playback progress, and overall state
@immutable
class AudioState {
  /// Whether audio is currently playing
  final bool isPlaying;

  /// Whether audio is currently paused (not stopped)
  final bool isPaused;

  /// The type of audio currently loaded/playing
  final AudioType currentAudioType;

  /// The prayer type if playing a prayer
  final PrayerType? currentPrayerType;

  /// The mystery ID if playing a mystery description
  final String? currentMysteryId;

  /// Current playback position in milliseconds
  final Duration currentPosition;

  /// Total duration of the current audio
  final Duration totalDuration;

  /// Whether the audio has completed
  final bool isCompleted;

  /// Error message if playback failed
  final String? errorMessage;

  /// Whether auto-advance is enabled when audio completes
  final bool autoAdvanceEnabled;

  const AudioState({
    this.isPlaying = false,
    this.isPaused = false,
    this.currentAudioType = AudioType.none,
    this.currentPrayerType,
    this.currentMysteryId,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.isCompleted = false,
    this.errorMessage,
    this.autoAdvanceEnabled = true,
  });

  /// Create a copy with updated fields
  AudioState copyWith({
    bool? isPlaying,
    bool? isPaused,
    AudioType? currentAudioType,
    PrayerType? currentPrayerType,
    String? currentMysteryId,
    Duration? currentPosition,
    Duration? totalDuration,
    bool? isCompleted,
    String? errorMessage,
    bool? autoAdvanceEnabled,
    bool clearError = false,
    bool clearMysteryId = false,
    bool clearPrayerType = false,
  }) {
    return AudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      currentAudioType: currentAudioType ?? this.currentAudioType,
      currentPrayerType: clearPrayerType
          ? null
          : (currentPrayerType ?? this.currentPrayerType),
      currentMysteryId: clearMysteryId
          ? null
          : (currentMysteryId ?? this.currentMysteryId),
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      isCompleted: isCompleted ?? this.isCompleted,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      autoAdvanceEnabled: autoAdvanceEnabled ?? this.autoAdvanceEnabled,
    );
  }

  /// Reset to initial state
  AudioState reset() {
    return const AudioState();
  }

  /// Get formatted current position (e.g., "1:23")
  String get formattedPosition {
    final minutes = currentPosition.inMinutes;
    final seconds = currentPosition.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted total duration (e.g., "2:45")
  String get formattedDuration {
    final minutes = totalDuration.inMinutes;
    final seconds = totalDuration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get progress as a value between 0.0 and 1.0
  double get progress {
    if (totalDuration.inMilliseconds == 0) return 0.0;
    return currentPosition.inMilliseconds / totalDuration.inMilliseconds;
  }

  /// Whether there is currently loaded audio
  bool get hasAudio => currentAudioType != AudioType.none;

  /// Whether the audio can be played (loaded but not playing)
  bool get canPlay => hasAudio && !isPlaying && !isCompleted;

  /// Whether the audio can be paused (currently playing)
  bool get canPause => isPlaying;

  /// Whether the audio can seek (has loaded audio)
  bool get canSeek => hasAudio && totalDuration.inMilliseconds > 0;

  /// Get a display name for the current audio
  String get displayName {
    switch (currentAudioType) {
      case AudioType.none:
        return 'No audio';
      case AudioType.prayer:
        return currentPrayerType?.displayName ?? 'Prayer';
      case AudioType.mystery:
        if (currentMysteryId != null) {
          return 'Mystery Description';
        }
        return 'Mystery';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioState &&
        other.isPlaying == isPlaying &&
        other.isPaused == isPaused &&
        other.currentAudioType == currentAudioType &&
        other.currentPrayerType == currentPrayerType &&
        other.currentMysteryId == currentMysteryId &&
        other.currentPosition == currentPosition &&
        other.totalDuration == totalDuration &&
        other.isCompleted == isCompleted &&
        other.autoAdvanceEnabled == autoAdvanceEnabled;
  }

  @override
  int get hashCode => Object.hash(
    isPlaying,
    isPaused,
    currentAudioType,
    currentPrayerType,
    currentMysteryId,
    currentPosition,
    totalDuration,
    isCompleted,
    autoAdvanceEnabled,
  );

  @override
  String toString() {
    return 'AudioState(type: $currentAudioType, playing: $isPlaying, '
        'position: $formattedPosition/$formattedDuration)';
  }
}

/// Types of audio that can be played
enum AudioType {
  /// No audio loaded
  none,

  /// A standard prayer audio file
  prayer,

  /// A mystery description audio file
  mystery;

  /// Get display name for this audio type
  String get displayName {
    switch (this) {
      case AudioType.none:
        return 'None';
      case AudioType.prayer:
        return 'Prayer';
      case AudioType.mystery:
        return 'Mystery';
    }
  }
}
