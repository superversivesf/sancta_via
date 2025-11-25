import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/base_settings_provider.dart';
import '../models/base_settings_model.dart';
import 'settings_section_header.dart';

/// A standardized accessibility settings section for all Sancta Via apps
class AccessibilitySettings extends ConsumerWidget {
  final bool showHeader;
  final bool showFontSize;
  final bool showTextScaling;
  final bool showReduceMotion;
  final bool showHapticFeedback;
  final String? fontPreviewText;

  const AccessibilitySettings({
    super.key,
    this.showHeader = true,
    this.showFontSize = true,
    this.showTextScaling = true,
    this.showReduceMotion = true,
    this.showHapticFeedback = true,
    this.fontPreviewText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(baseSettingsProvider);
    final effectiveScale = ref.watch(effectiveTextScaleProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        if (showHeader) const SettingsSectionHeader(title: 'Accessibility'),

        // Font size setting
        if (showFontSize)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.text_fields),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Font Size',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Slider with icons
                Row(
                  children: [
                    const Icon(Icons.text_decrease, size: 16),
                    Expanded(
                      child: Slider(
                        value: settings.fontSize,
                        min: 12.0,
                        max: 32.0,
                        divisions: 20,
                        label:
                            '${settings.fontSize.round()}pt (${settings.fontSizeLabel})',
                        onChanged: (value) {
                          ref
                              .read(baseSettingsProvider.notifier)
                              .setFontSize(value);
                        },
                      ),
                    ),
                    const Icon(Icons.text_increase, size: 20),
                  ],
                ),

                // Current value display
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Text(
                    '${settings.fontSize.round()}pt - ${settings.fontSizeLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),

                // Preview text
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preview',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        fontPreviewText ??
                            'Sample text: "Be it done unto me according to thy word."',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontSize: settings.fontSize,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Text scaling preset
        if (showTextScaling)
          ListTile(
            leading: const Icon(Icons.accessibility),
            title: const Text('Text Scaling'),
            subtitle: Text(
                'System accessibility scaling: ${settings.textScalingMode.displayName}'),
            trailing: DropdownButton<TextScalingMode>(
              value: settings.textScalingMode,
              onChanged: (TextScalingMode? newValue) {
                if (newValue != null) {
                  ref
                      .read(baseSettingsProvider.notifier)
                      .setTextScalingMode(newValue);
                }
              },
              items: TextScalingMode.values.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(mode.displayName),
                );
              }).toList(),
            ),
          ),

        // Effective scale display
        if (showTextScaling && showFontSize)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Effective text scale: ${effectiveScale.toStringAsFixed(2)}x',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withOpacity(0.6),
                  ),
            ),
          ),

        // Reduce motion setting
        if (showReduceMotion)
          SwitchListTile(
            secondary: const Icon(Icons.motion_photos_off),
            title: const Text('Reduce Motion'),
            subtitle: const Text('Minimize animations and transitions'),
            value: settings.reduceMotion,
            onChanged: (bool value) {
              ref.read(baseSettingsProvider.notifier).setReduceMotion(value);
            },
          ),

        // Haptic feedback setting
        if (showHapticFeedback)
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('Haptic Feedback'),
            subtitle: const Text('Vibration feedback for interactions'),
            value: settings.hapticFeedbackEnabled,
            onChanged: (bool value) {
              ref
                  .read(baseSettingsProvider.notifier)
                  .setHapticFeedbackEnabled(value);
            },
          ),
      ],
    );
  }
}

/// Compact accessibility quick toggles
class AccessibilityQuickToggles extends ConsumerWidget {
  const AccessibilityQuickToggles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(baseSettingsProvider);

    return Wrap(
      spacing: 8.0,
      children: [
        FilterChip(
          label: const Text('Reduce Motion'),
          selected: settings.reduceMotion,
          onSelected: (selected) {
            ref.read(baseSettingsProvider.notifier).setReduceMotion(selected);
          },
        ),
        FilterChip(
          label: const Text('Haptic Feedback'),
          selected: settings.hapticFeedbackEnabled,
          onSelected: (selected) {
            ref
                .read(baseSettingsProvider.notifier)
                .setHapticFeedbackEnabled(selected);
          },
        ),
      ],
    );
  }
}

/// Text scaling info widget
class TextScalingInfo extends ConsumerWidget {
  const TextScalingInfo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(baseSettingsProvider);
    final effectiveScale = ref.watch(effectiveTextScaleProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Text Scaling Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Font Size: ${settings.fontSize.round()}pt (${settings.fontSizeLabel})',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Accessibility Mode: ${settings.textScalingMode.displayName} (${settings.textScalingMode.scaleFactor}x)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Effective Scale: ${effectiveScale.toStringAsFixed(2)}x',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
