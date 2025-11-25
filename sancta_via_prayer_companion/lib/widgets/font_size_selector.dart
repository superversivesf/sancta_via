// MIGRATION: This widget has been updated to use the unified settings system
// while maintaining backward compatibility and enhancing the functionality

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/prayer_app_settings_provider.dart';

class FontSizeSlider extends ConsumerWidget {
  const FontSizeSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(prayerAppSettingsProvider);
    final currentFontSize = settings.fontSize;

    return Column(
      children: [
        // Font size slider with icons
        Row(
          children: [
            const Icon(Icons.text_decrease, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                value: currentFontSize,
                min: 12.0,
                max: 32.0, // Updated to new unified range
                divisions: 20,
                label:
                    '${currentFontSize.round()}pt (${_getFontSizeLabel(currentFontSize)})',
                onChanged: (value) {
                  ref
                      .read(prayerAppSettingsProvider.notifier)
                      .updateFontSize(value);
                },
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.text_increase, size: 20),
          ],
        ),

        // Current font size display
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${currentFontSize.round()}pt - ${_getFontSizeLabel(currentFontSize)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        const SizedBox(height: 12),

        // Sample prayer text with current settings
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(6.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sample Prayer Text:',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Our Father, who art in heaven,\nhallowed be thy name.',
                style: TextStyle(fontSize: currentFontSize, height: 1.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Effective scale: ${settings.effectiveTextScaleFactor.toStringAsFixed(2)}x',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getFontSizeLabel(double value) {
    if (value <= 12) return 'Smallest';
    if (value <= 14) return 'Smaller';
    if (value <= 16) return 'Small';
    if (value <= 18) return 'Normal';
    if (value <= 20) return 'Large';
    if (value <= 24) return 'Larger';
    return 'Largest';
  }
}
