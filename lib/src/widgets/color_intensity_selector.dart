import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_providers.dart';

class ColorIntensitySelector extends ConsumerWidget {
  final Widget? leading;
  final String? title;
  final String? subtitle;

  const ColorIntensitySelector({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorIntensity = ref.watch(colorIntensityProvider);

    return ListTile(
      leading: leading ?? const Icon(Icons.palette),
      title: Text(title ?? 'Color Intensity'),
      subtitle: Text(subtitle ?? '${colorIntensity.displayName} liturgical colors'),
      trailing: DropdownButton<ColorIntensity>(
        value: colorIntensity,
        onChanged: (ColorIntensity? newValue) {
          if (newValue != null) {
            ref.read(colorIntensityProvider.notifier).setColorIntensity(newValue);
          }
        },
        items: ColorIntensity.values.map((intensity) {
          return DropdownMenuItem(
            value: intensity,
            child: Text(intensity.displayName),
          );
        }).toList(),
      ),
    );
  }
}