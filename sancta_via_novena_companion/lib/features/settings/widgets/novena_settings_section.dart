import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import '../providers/novena_app_settings_provider.dart';
import '../services/settings_service.dart';
import '../services/settings_error_handler.dart';
import '../widgets/time_picker_dialog.dart' as custom_time_picker;

/// Novena-specific settings section
class NovenaSettingsSection extends ConsumerWidget {
  const NovenaSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(novenaAppSettingsProvider);
    final settingsService = ref.read(settingsServiceProvider);

    return Column(
      children: [
        const SettingsSectionHeader(title: 'Novena Settings'),
        const SizedBox(height: 8),

        // Daily reminder time
        ListTile(
          leading: const Icon(Icons.schedule),
          title: const Text('Daily Reminder Time'),
          subtitle: const Text(
            'Set your preferred time for novena prayer reminders',
          ),
          isThreeLine: false,
          trailing: Semantics(
            label: 'Current reminder time: ${settings.dailyReminderTimeOfDay.format(context)}',
            child: Text(
              settings.dailyReminderTimeOfDay.format(context),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          onTap: () => _showTimePickerDialog(context, ref, settingsService),
        ),
        const SizedBox(height: 4),

        // Show completion celebrations
        SwitchListTile(
          secondary: const Icon(Icons.celebration),
          title: const Text('Completion Celebrations'),
          subtitle: const Text('Show celebrations when completing novena days'),
          value: settings.showCompletionCelebrations,
          onChanged: (value) => _toggleCompletionCelebrations(
            context, 
            ref, 
            settingsService, 
            value,
          ),
        ),
        const SizedBox(height: 4),

        // Allow multiple novenas (future feature)
        SwitchListTile(
          secondary: const Icon(Icons.layers),
          title: const Text('Multiple Novenas'),
          subtitle: const Text('Allow multiple active novenas (coming soon)'),
          value: settings.allowMultipleNovenas,
          onChanged: null, // Disabled for now
        ),
      ],
    );
  }

  Future<void> _showTimePickerDialog(
    BuildContext context,
    WidgetRef ref,
    SettingsService settingsService,
  ) async {
    final currentTime = settingsService.currentReminderTime;
    
    final pickedTime = await custom_time_picker.CustomTimePickerDialog.show(
      context: context,
      initialTime: currentTime,
    );
    
    if (pickedTime != null && pickedTime != currentTime && context.mounted) {
      try {
        await settingsService.updateReminderTime(pickedTime);
        if (context.mounted) {
          SettingsErrorHandler.showSuccess(
            context,
            'Daily reminder time updated to ${pickedTime.format(context)}',
          );
        }
      } catch (e) {
        if (context.mounted) {
          SettingsErrorHandler.handleError(
            context,
            e as Exception,
            operation: 'updating reminder time',
          );
        }
      }
    }
  }

  Future<void> _toggleCompletionCelebrations(
    BuildContext context,
    WidgetRef ref,
    SettingsService settingsService,
    bool value,
  ) async {
    try {
      await settingsService.toggleCompletionCelebrations(value);
      if (context.mounted) {
        SettingsErrorHandler.showSuccess(
          context,
          value 
              ? 'Completion celebrations enabled'
              : 'Completion celebrations disabled',
        );
      }
    } catch (e) {
      if (context.mounted) {
        SettingsErrorHandler.handleError(
          context,
          e as Exception,
          operation: 'toggling completion celebrations',
        );
      }
    }
  }
}
