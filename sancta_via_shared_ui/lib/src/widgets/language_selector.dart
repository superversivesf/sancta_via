import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/base_settings_provider.dart';
import '../models/base_settings_model.dart';

/// A standardized language selector widget used across all Sancta Via apps
class LanguageSelector extends ConsumerWidget {
  final Widget? leading;
  final String? title;
  final String? subtitle;
  final bool dropdownOnly;
  final List<AppLanguage>? availableLanguages;

  const LanguageSelector({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.dropdownOnly = false,
    this.availableLanguages,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(defaultLanguageProvider);
    final languages = availableLanguages ?? AppLanguage.values;

    // If dropdownOnly is true, return just the dropdown
    if (dropdownOnly) {
      return DropdownButton<AppLanguage>(
        value: currentLanguage,
        onChanged: (AppLanguage? newValue) {
          if (newValue != null) {
            ref
                .read(baseSettingsProvider.notifier)
                .setDefaultLanguage(newValue);
          }
        },
        isExpanded: false,
        underline: const SizedBox.shrink(), // Remove underline
        items: languages.map((language) {
          return DropdownMenuItem(
            value: language,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _getLanguageFlag(language),
                const SizedBox(width: 8),
                Text(
                  language.displayName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    // Otherwise return the full ListTile
    return ListTile(
      leading: leading ?? const Icon(Icons.language),
      title: Text(title ?? 'Default Language'),
      subtitle: Text(subtitle ?? 'Choose language preference'),
      trailing: DropdownButton<AppLanguage>(
        value: currentLanguage,
        onChanged: (AppLanguage? newValue) {
          if (newValue != null) {
            ref
                .read(baseSettingsProvider.notifier)
                .setDefaultLanguage(newValue);
          }
        },
        items: languages.map((language) {
          return DropdownMenuItem(
            value: language,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _getLanguageFlag(language),
                const SizedBox(width: 8),
                Text(language.displayName),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _getLanguageFlag(AppLanguage language) {
    // Simple flag icons - could be replaced with actual flag images
    String flag;
    switch (language) {
      case AppLanguage.english:
        flag = '🇺🇸';
        break;
      case AppLanguage.latin:
        flag = '⛪'; // Church icon for Latin
        break;
      case AppLanguage.spanish:
        flag = '🇪🇸';
        break;
    }

    return Text(
      flag,
      style: const TextStyle(fontSize: 16),
    );
  }
}

/// Compact language display widget
class LanguageDisplay extends ConsumerWidget {
  final bool showFlag;

  const LanguageDisplay({
    super.key,
    this.showFlag = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(defaultLanguageProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFlag) ...[
          _getLanguageFlag(currentLanguage),
          const SizedBox(width: 4),
        ],
        Text(currentLanguage.displayName),
      ],
    );
  }

  Widget _getLanguageFlag(AppLanguage language) {
    String flag;
    switch (language) {
      case AppLanguage.english:
        flag = '🇺🇸';
        break;
      case AppLanguage.latin:
        flag = '⛪';
        break;
      case AppLanguage.spanish:
        flag = '🇪🇸';
        break;
    }

    return Text(
      flag,
      style: const TextStyle(fontSize: 14),
    );
  }
}

/// Language picker dialog
class LanguagePickerDialog extends ConsumerWidget {
  final List<AppLanguage>? availableLanguages;

  const LanguagePickerDialog({
    super.key,
    this.availableLanguages,
  });

  static Future<AppLanguage?> show(
    BuildContext context, {
    List<AppLanguage>? availableLanguages,
  }) {
    return showDialog<AppLanguage>(
      context: context,
      builder: (context) => LanguagePickerDialog(
        availableLanguages: availableLanguages,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(defaultLanguageProvider);
    final languages = availableLanguages ?? AppLanguage.values;

    return AlertDialog(
      title: const Text('Select Language'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: languages.map((language) {
          return RadioListTile<AppLanguage>(
            value: language,
            groupValue: currentLanguage,
            onChanged: (AppLanguage? value) {
              if (value != null) {
                Navigator.of(context).pop(value);
              }
            },
            title: Row(
              children: [
                _getLanguageFlag(language),
                const SizedBox(width: 12),
                Text(language.displayName),
              ],
            ),
            subtitle: Text('Code: ${language.code}'),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _getLanguageFlag(AppLanguage language) {
    String flag;
    switch (language) {
      case AppLanguage.english:
        flag = '🇺🇸';
        break;
      case AppLanguage.latin:
        flag = '⛪';
        break;
      case AppLanguage.spanish:
        flag = '🇪🇸';
        break;
    }

    return Text(
      flag,
      style: const TextStyle(fontSize: 20),
    );
  }
}
