import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/prayer_providers.dart';

class FontSizeSlider extends ConsumerWidget {
  const FontSizeSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFontSize = ref.watch(fontSizeProvider);
    
    return Column(
      children: [
        // Font size slider with labels
        Row(
          children: [
            const Icon(Icons.text_decrease, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                value: currentFontSize,
                min: 12.0,
                max: 27.0,
                divisions: 10,
                onChanged: (value) {
                  ref.read(prayerPreferencesProvider.notifier).updateFontSize(value);
                },
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.text_increase, size: 20),
          ],
        ),
        
        // Size labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Small',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                'Large',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}