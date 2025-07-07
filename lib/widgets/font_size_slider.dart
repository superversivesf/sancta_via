// MIGRATION: This widget has been updated to use the unified settings system
// while maintaining backward compatibility

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/confession_app_settings_provider.dart';

class FontSizeSlider extends ConsumerWidget {
  const FontSizeSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(confessionAppSettingsProvider);
    
    // Convert fontSize back to textScale for display (maintains same UI behavior)
    final textScale = settings.textScale;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('A', style: TextStyle(fontSize: 12)),
            const Text('A', style: TextStyle(fontSize: 16)),
            const Text('A', style: TextStyle(fontSize: 20)),
          ],
        ),
        Slider(
          value: textScale,
          min: 0.8,
          max: 1.5,
          divisions: 7,
          onChanged: (value) {
            // Use the new provider method that handles conversion
            ref.read(confessionAppSettingsProvider.notifier).updateTextScale(value);
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sample text at current size',
              style: TextStyle(fontSize: settings.fontSize),
            ),
            Text(
              '${settings.fontSize.round()}pt',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
