import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_settings_provider.dart';

class FontSizeSlider extends ConsumerWidget {
  const FontSizeSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    
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
          value: settings.textScale,
          min: 0.8,
          max: 1.5,
          divisions: 7,
          onChanged: (value) {
            ref.read(appSettingsProvider.notifier).updateTextScale(value);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Sample text at current size',
          style: TextStyle(fontSize: 16 * settings.textScale),
        ),
      ],
    );
  }
}
