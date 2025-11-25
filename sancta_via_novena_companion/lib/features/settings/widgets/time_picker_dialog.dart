import 'package:flutter/material.dart';

/// Custom time picker dialog for better UX
class CustomTimePickerDialog {
  /// Show time picker with improved styling
  static Future<TimeOfDay?> show({
    required BuildContext context,
    required TimeOfDay initialTime,
    String? title,
  }) async {
    return await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: title ?? 'Select Reminder Time',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              hourMinuteTextColor: Theme.of(context).colorScheme.primary,
              dayPeriodTextColor: Theme.of(context).colorScheme.primary,
              dialHandColor: Theme.of(context).colorScheme.primary,
              dialTextColor: Theme.of(context).colorScheme.onSurface,
              entryModeIconColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
