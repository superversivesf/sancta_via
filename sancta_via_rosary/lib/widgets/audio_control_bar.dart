import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_state.dart';
import '../models/mystery_set.dart';
import '../models/prayer_type.dart';
import '../providers/audio_provider.dart';

/// Audio control bar widget that appears at the bottom of the screen
/// when audio is available or playing.
///
/// Shows play/pause button, progress bar, and time display.
class AudioControlBar extends ConsumerWidget {
  /// Creates an audio control bar
  const AudioControlBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioStateProvider);
    final controller = ref.read(audioControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Only show if there's audio loaded or it's playing
    if (!state.hasAudio && !state.isPlaying && !state.isPaused) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Audio title
          Row(
            children: [
              Icon(
                _getAudioIcon(state.currentAudioType),
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.displayName,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Close button
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: controller.stop,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar and controls
          Row(
            children: [
              // Play/Pause button
              _buildPlayPauseButton(state, controller, colorScheme),
              const SizedBox(width: 12),
              // Progress bar
              Expanded(
                child: _buildProgressBar(
                  state,
                  controller,
                  colorScheme,
                  context,
                ),
              ),
              const SizedBox(width: 12),
              // Time display
              Text(
                '${state.formattedPosition} / ${state.formattedDuration}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseButton(
    AudioState state,
    AudioController controller,
    ColorScheme colorScheme,
  ) {
    return Material(
      color: colorScheme.primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: controller.togglePlayPause,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            state.isPlaying ? Icons.pause : Icons.play_arrow,
            color: colorScheme.onPrimary,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(
    AudioState state,
    AudioController controller,
    ColorScheme colorScheme,
    BuildContext context,
  ) {
    return GestureDetector(
      onTapUp: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final localPosition = box.globalToLocal(details.globalPosition);
        final width = box.size.width - 88; // Account for button and time
        final progress =
            (localPosition.dx - 52) / width; // 52 = button + spacing
        final clampedProgress = progress.clamp(0.0, 1.0);
        final position = Duration(
          milliseconds: (clampedProgress * state.totalDuration.inMilliseconds)
              .round(),
        );
        controller.seekTo(position);
      },
      child: Container(
        height: 24,
        alignment: Alignment.center,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Background track
                Container(
                  height: 4,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Progress fill
                Container(
                  height: 4,
                  width: constraints.maxWidth * state.progress,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Progress handle
                Positioned(
                  left: (constraints.maxWidth * state.progress) - 6,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.surface, width: 2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _getAudioIcon(AudioType type) {
    switch (type) {
      case AudioType.prayer:
        return Icons.record_voice_over;
      case AudioType.mystery:
        return Icons.auto_stories;
      case AudioType.none:
        return Icons.music_note;
    }
  }
}

/// Audio button that can be added to prayer cards
///
/// Shows a speaker icon that plays the associated prayer audio
class AudioPrayerButton extends ConsumerWidget {
  /// The type of prayer to play
  final PrayerType prayerType;

  /// Optional callback when audio completes
  final VoidCallback? onComplete;

  /// Creates an audio prayer button
  const AudioPrayerButton({
    super.key,
    required this.prayerType,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioStateProvider);
    final controller = ref.read(audioControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Check if this specific prayer is currently playing
    final isThisPlaying =
        state.isPlaying &&
        state.currentAudioType == AudioType.prayer &&
        state.currentPrayerType == prayerType;

    final isThisPaused =
        state.isPaused &&
        state.currentAudioType == AudioType.prayer &&
        state.currentPrayerType == prayerType;

    return IconButton.filledTonal(
      icon: Icon(
        isThisPlaying
            ? Icons.pause_circle_filled
            : isThisPaused
            ? Icons.play_circle_filled
            : Icons.volume_up,
      ),
      onPressed: () {
        if (isThisPlaying) {
          controller.pause();
        } else if (isThisPaused) {
          controller.resume();
        } else {
          controller.playPrayer(prayerType, onComplete: onComplete);
        }
      },
      tooltip: isThisPlaying ? 'Pause' : 'Play audio',
      style: IconButton.styleFrom(
        backgroundColor: isThisPlaying || isThisPaused
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

/// Audio button for mystery descriptions
///
/// Shows a speaker icon that plays the mystery description audio
class AudioMysteryButton extends ConsumerWidget {
  /// The mystery number (1-5)
  final int mysteryNumber;

  /// The mystery set
  final MysterySet mysterySet;

  /// Optional callback when audio completes
  final VoidCallback? onComplete;

  /// Creates an audio mystery button
  const AudioMysteryButton({
    super.key,
    required this.mysteryNumber,
    required this.mysterySet,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioStateProvider);
    final controller = ref.read(audioControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Check if this specific mystery is currently playing
    final expectedMysteryId = '${_getSetName(mysterySet)}_$mysteryNumber';
    final isThisPlaying =
        state.isPlaying &&
        state.currentAudioType == AudioType.mystery &&
        state.currentMysteryId == expectedMysteryId;

    final isThisPaused =
        state.isPaused &&
        state.currentAudioType == AudioType.mystery &&
        state.currentMysteryId == expectedMysteryId;

    return IconButton.filledTonal(
      icon: Icon(
        isThisPlaying
            ? Icons.pause_circle_filled
            : isThisPaused
            ? Icons.play_circle_filled
            : Icons.volume_up,
      ),
      onPressed: () {
        if (isThisPlaying) {
          controller.pause();
        } else if (isThisPaused) {
          controller.resume();
        } else {
          controller.playMysteryDescription(
            mysteryNumber,
            mysterySet,
            onComplete: onComplete,
          );
        }
      },
      tooltip: isThisPlaying ? 'Pause' : 'Play description',
      style: IconButton.styleFrom(
        backgroundColor: isThisPlaying || isThisPaused
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
      ),
    );
  }

  String _getSetName(MysterySet set) {
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
