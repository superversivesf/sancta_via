import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/base_settings_provider.dart';
import '../models/base_settings_model.dart';

/// A standardized font size selector widget used across all Sancta Via apps
class FontSizeSelector extends ConsumerWidget {
  final Widget? leading;
  final String? title;
  final String? subtitle;
  final bool showPreview;
  final String? previewText;
  final bool showSlider;
  final bool showDropdown;

  const FontSizeSelector({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.showPreview = true,
    this.previewText,
    this.showSlider = true,
    this.showDropdown = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(baseSettingsProvider);
    final effectiveScale = ref.watch(effectiveTextScaleProvider);

    // If only showing dropdown, return just the dropdown
    if (showDropdown && !showSlider) {
      return DropdownButton<TextScalingMode>(
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
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        if (title != null || leading != null)
          ListTile(
            leading: leading ?? const Icon(Icons.text_fields),
            title: Text(title ?? 'Font Size'),
            subtitle: subtitle != null ? Text(subtitle!) : null,
          ),

        // Slider for fine-grained control
        if (showSlider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              ],
            ),
          ),

        // Dropdown for accessibility presets
        if (showDropdown)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                const Text('Accessibility: '),
                DropdownButton<TextScalingMode>(
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
              ],
            ),
          ),

        // Preview text
        if (showPreview)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
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
                    previewText ??
                        'Sample text: "Be it done unto me according to thy word."',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: settings.fontSize,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Effective scale: ${effectiveScale.toStringAsFixed(2)}x',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact font size selector for use in ListTiles
class CompactFontSizeSelector extends ConsumerWidget {
  const CompactFontSizeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(baseSettingsProvider);

    return ListTile(
      leading: const Icon(Icons.text_fields),
      title: const Text('Font Size'),
      subtitle:
          Text('${settings.fontSize.round()}pt - ${settings.fontSizeLabel}'),
      trailing: SizedBox(
        width: 120,
        child: Slider(
          value: settings.fontSize,
          min: 12.0,
          max: 32.0,
          divisions: 20,
          onChanged: (value) {
            ref.read(baseSettingsProvider.notifier).setFontSize(value);
          },
        ),
      ),
    );
  }
}

/// Simple font size slider without labels
class FontSizeSlider extends ConsumerWidget {
  final double? min;
  final double? max;
  final int? divisions;

  const FontSizeSlider({
    super.key,
    this.min,
    this.max,
    this.divisions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(fontSizeProvider);

    return Slider(
      value: fontSize,
      min: min ?? 12.0,
      max: max ?? 32.0,
      divisions: divisions ?? 20,
      label: '${fontSize.round()}pt',
      onChanged: (value) {
        ref.read(baseSettingsProvider.notifier).setFontSize(value);
      },
    );
  }
}
