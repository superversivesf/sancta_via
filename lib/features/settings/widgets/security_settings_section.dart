import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import '../providers/novena_app_settings_provider.dart';

import '../services/settings_error_handler.dart';
import '../widgets/pin_management_dialog.dart';
import '../../../config/constants.dart';

/// Security settings section for PIN management
class SecuritySettingsSection extends ConsumerWidget {
  const SecuritySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(novenaAppSettingsProvider);

    return Column(
      children: [
        const SettingsSectionHeader(title: 'Security'),
        const SizedBox(height: 8),

        // PIN Code Management
        ListTile(
          leading: const Icon(Icons.lock),
          title: Text(settings.hasPinCode ? 'Change PIN Code' : 'Set PIN Code'),
          subtitle: Text(settings.hasPinCode 
              ? 'PIN is currently set for examination data protection'
              : 'Create a ${AppConstants.pinLength}-digit PIN to protect examination data'),
          trailing: settings.hasPinCode 
              ? const Icon(Icons.edit)
              : const Icon(Icons.add),
          onTap: () => _handlePinAction(context, ref, isChange: settings.hasPinCode),
        ),
        const SizedBox(height: 4),

        if (settings.hasPinCode)
          ListTile(
            leading: const Icon(Icons.lock_open, color: Colors.orange),
            title: const Text('Remove PIN Code'),
            subtitle: const Text('Remove PIN protection (not recommended)'),
            onTap: () => _handleRemovePin(context, ref),
          ),
      ],
    );
  }

  Future<void> _handlePinAction(
    BuildContext context,
    WidgetRef ref, {
    required bool isChange,
  }) async {
    try {
      if (isChange) {
        await PinManagementDialog.showChangePin(context, ref);
      } else {
        await PinManagementDialog.showSetupPin(context, ref);
      }
    } catch (e) {
      if (context.mounted) {
        SettingsErrorHandler.handleError(
          context,
          e as Exception,
          operation: isChange ? 'changing PIN' : 'setting up PIN',
        );
      }
    }
  }

  Future<void> _handleRemovePin(BuildContext context, WidgetRef ref) async {
    try {
      final confirmed = await SettingsErrorHandler.showConfirmationDialog(
        context,
        title: 'Remove PIN Code',
        message: 'Are you sure you want to remove PIN protection? This is not recommended.',
        confirmText: 'Remove PIN',
        confirmColor: Colors.orange,
      );

      if (confirmed && context.mounted) {
        await PinManagementDialog.showRemovePin(context, ref);
      }
    } catch (e) {
      if (context.mounted) {
        SettingsErrorHandler.handleError(
          context,
          e as Exception,
          operation: 'removing PIN',
        );
      }
    }
  }
}
