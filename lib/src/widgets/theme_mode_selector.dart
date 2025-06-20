import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_providers.dart';
import '../extensions/theme_extensions.dart';

class ThemeModeSelector extends ConsumerWidget {
  final Widget? leading;
  final String? title;
  final String? subtitle;

  const ThemeModeSelector({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return ListTile(
      leading: leading ?? const Icon(Icons.brightness_6),
      title: Text(title ?? 'Theme Mode'),
      subtitle: Text(subtitle ?? themeMode.displayName),
      trailing: DropdownButton<ThemeMode>(
        value: themeMode,
        onChanged: (ThemeMode? newValue) {
          if (newValue != null) {
            ref.read(themeModeProvider.notifier).setThemeMode(newValue);
          }
        },
        items: ThemeMode.values.map((mode) {
          return DropdownMenuItem(
            value: mode,
            child: Text(mode.displayName),
          );
        }).toList(),
      ),
    );
  }
}