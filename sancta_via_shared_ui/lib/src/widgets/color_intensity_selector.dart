import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_providers.dart';

class ColorIntensitySelector extends ConsumerWidget {
  final Widget? leading;
  final String? title;
  final String? subtitle;
  final bool dropdownOnly;

  const ColorIntensitySelector({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.dropdownOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorIntensity = ref.watch(colorIntensityProvider);

    // If dropdownOnly is true, return just the dropdown
    if (dropdownOnly) {
      return DropdownButton<ColorIntensity>(
        value: colorIntensity,
        onChanged: (ColorIntensity? newValue) {
          if (newValue != null) {
            ref
                .read(colorIntensityProvider.notifier)
                .setColorIntensity(newValue);
          }
        },
        isExpanded: false,
        underline: const SizedBox.shrink(), // Remove underline
        items: ColorIntensity.values.map((intensity) {
          return DropdownMenuItem(
            value: intensity,
            child: Text(
              intensity.displayName,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }).toList(),
      );
    }

    // Otherwise return the full ListTile
    return ListTile(
      leading: leading ?? const Icon(Icons.palette),
      title: Text(title ?? 'Color Intensity'),
      subtitle:
          Text(subtitle ?? '${colorIntensity.displayName} liturgical colors'),
      trailing: DropdownButton<ColorIntensity>(
        value: colorIntensity,
        onChanged: (ColorIntensity? newValue) {
          if (newValue != null) {
            ref
                .read(colorIntensityProvider.notifier)
                .setColorIntensity(newValue);
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
