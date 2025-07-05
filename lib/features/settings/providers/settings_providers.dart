// MIGRATION: This file has been updated to use the unified settings system
// The old implementation is preserved for backward compatibility

export 'novena_app_settings_provider.dart';

// Re-export the legacy provider for backward compatibility
import 'novena_app_settings_provider.dart';

// Legacy settings provider that delegates to the new unified system
final settingsProvider = legacySettingsProvider;