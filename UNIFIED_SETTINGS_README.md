# Unified Settings System for Sancta Via Apps

This document describes the new unified settings system that standardizes settings management across all Sancta Via Catholic lifestyle apps.

## Overview

The unified settings system provides:
- **Common Settings Model** - Shared settings that all apps need
- **Standardized UI Components** - Consistent settings interface
- **Unified Data Persistence** - Consistent storage approach
- **Accessibility Features** - Built-in accessibility support
- **App-Specific Extensions** - Easy customization for each app

## Architecture

### Base Settings Model (`BaseSettingsModel`)

The foundation of the system is `BaseSettingsModel` which includes:

```dart
class BaseSettingsModel {
  final double fontSize;                    // 12.0-32.0 pts
  final TextScalingMode textScalingMode;    // Small/Normal/Large/ExtraLarge
  final AppLanguage defaultLanguage;        // English/Latin/Spanish
  final bool notificationsEnabled;          // Global notifications toggle
  final bool showLiturgicalColors;          // Liturgical color indicators
  final bool hapticFeedbackEnabled;         // Haptic feedback
  final bool reduceMotion;                  // Accessibility: reduce animations
}
```

### Providers

- `baseSettingsProvider` - Main settings provider
- `fontSizeProvider` - Font size convenience provider
- `defaultLanguageProvider` - Language convenience provider
- `effectiveTextScaleProvider` - Combined scaling factor

### UI Components

#### Core Settings Components
- `FontSizeSelector` - Standardized font size control
- `LanguageSelector` - Language selection with flags
- `AccessibilitySettings` - Complete accessibility section
- `NotificationsSettings` - Notifications management
- `AppInfoSection` - Standardized about section

#### Existing Theme Components (Enhanced)
- `ThemeModeSelector` - Light/Dark/System theme
- `ColorIntensitySelector` - Vibrant/Muted colors
- `LiturgicalColorPreview` - Liturgical color display

## Usage

### Quick Start - Use Complete Unified Screen

```dart
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

class MyAppSettingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appInfo = AppInfo(
      appName: 'My Catholic App',
      version: '1.0.0',
      description: 'A Catholic app for the faithful...',
      icon: Icon(Icons.church, size: 48),
    );

    return UnifiedSettingsScreen(
      appInfo: appInfo,
      appSpecificSettings: _buildAppSpecificSettings(),
    );
  }

  Widget _buildAppSpecificSettings() {
    return Column(
      children: [
        SettingsSectionHeader(title: 'App-Specific Settings'),
        // Your custom settings here
        ListTile(/* custom setting */),
      ],
    );
  }
}
```

### Individual Components

```dart
// Font size with preview
FontSizeSelector(
  showPreview: true,
  previewText: 'Sample prayer text...',
)

// Language selection
LanguageSelector(
  title: 'Prayer Language',
  availableLanguages: [AppLanguage.english, AppLanguage.latin],
)

// Complete accessibility section
AccessibilitySettings(
  fontPreviewText: 'Hail Mary, full of grace...',
)

// Notifications with custom options
NotificationsSettings(
  customOptions: [
    CatholicNotificationOptions.prayerReminders(),
    CatholicNotificationOptions.liturgicalCalendar(),
  ],
)
```

### Accessing Settings in Your App

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Access individual settings
    final fontSize = ref.watch(fontSizeProvider);
    final language = ref.watch(defaultLanguageProvider);
    final effectiveScale = ref.watch(effectiveTextScaleProvider);
    
    // Access full settings model
    final settings = ref.watch(baseSettingsProvider);
    
    return Text(
      'Sample text',
      style: TextStyle(
        fontSize: fontSize,
        // Use effectiveScale for complete scaling
      ),
    );
  }
}
```

## Migration Guide

### App-by-App Migration

#### 1. Bible Reading App
**Current Issues:**
- Custom `AppSettings` model with limited scope
- Font size range inconsistency
- Mixed text scaling approaches

**Migration Steps:**
```dart
// BEFORE: Custom settings
class AppSettings {
  final double fontSize;
  final BibleTranslation selectedBibleTranslation;
}

// AFTER: Extend base settings
class BibleAppSettings extends BaseSettingsModel {
  final BibleTranslation selectedBibleTranslation;
  
  BibleAppSettings({
    required this.selectedBibleTranslation,
    super.fontSize,
    super.textScalingMode,
    // ... other base settings
  });
}
```

#### 2. Confession Companion
**Current Issues:**
- Deprecated `darkMode` (use theme providers instead)
- `textScale` multiplier (standardize to fontSize + textScalingMode)
- JSON serialization inconsistencies

**Migration Steps:**
```dart
// BEFORE: Custom provider
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  // Custom implementation
}

// AFTER: Extend base provider
class ConfessionSettingsNotifier extends StateNotifier<ConfessionSettings> {
  ConfessionSettingsNotifier() : super(ConfessionSettings.defaults()) {
    // Migrate existing preferences
    _migrateFromOldSettings();
  }
  
  Future<void> _migrateFromOldSettings() async {
    // Read old settings and convert to new format
    final prefs = await SharedPreferences.getInstance();
    final oldSettings = prefs.getString('confession_settings');
    if (oldSettings != null) {
      // Convert and save in new format
      final migrated = _convertOldToNew(oldSettings);
      final baseSettings = ref.read(baseSettingsProvider.notifier);
      await baseSettings.updateSettings(migrated);
    }
  }
}
```

#### 3. Novena Companion
**Current Issues:**
- Custom `ColorSchemeStyle` enum (use ColorIntensity instead)
- Font size as multiplier (standardize to points)
- PIN code management (keep app-specific)

**Migration Steps:**
```dart
// BEFORE: Custom settings model
class SettingsModel {
  final double fontSize;  // multiplier
  final ColorSchemeStyle colorSchemeStyle;
  final bool hasPinCode;
}

// AFTER: Use base + app-specific
class NovenaSettings {
  final BaseSettingsModel baseSettings;
  final bool hasPinCode;  // Keep PIN management app-specific
  
  // Access base settings through composition
  double get fontSize => baseSettings.fontSize;
  ColorIntensity get colorIntensity => /* convert from theme provider */;
}
```

#### 4. Prayer Companion
**Current Issues:**
- Complex `PrayerPreferences` model mixing UI and content preferences
- Custom reading modes (keep app-specific)
- Font size range inconsistency

**Migration Steps:**
```dart
// BEFORE: Monolithic preferences
class PrayerPreferences {
  final double fontSize;  // App-specific range
  final PrayerReadingMode readingMode;  // App-specific
  final String defaultLanguage;  // Move to base
  final bool verseHighlighting;  // App-specific
}

// AFTER: Separate concerns
class PrayerAppSettings {
  final BaseSettingsModel baseSettings;  // Common settings
  final PrayerReadingMode readingMode;   // App-specific
  final bool verseHighlighting;          // App-specific
  final List<String> favoritePrayerIds;  // App-specific
}
```

#### 5. Liturgical Calendar App
**Status:** ✅ Already mostly standardized!
- Already uses shared UI components
- Minimal custom settings needed
- Good example for other apps

### Data Migration Strategy

1. **Gradual Migration:**
   ```dart
   class MigrationHelper {
     static Future<void> migrateAppSettings() async {
       final prefs = await SharedPreferences.getInstance();
       
       // Check if old settings exist
       if (prefs.containsKey('old_settings_key')) {
         final oldData = prefs.getString('old_settings_key');
         final newSettings = convertOldToNew(oldData);
         
         // Save in new format
         await prefs.setString('sancta_via_base_settings', 
             json.encode(newSettings.toJson()));
         
         // Remove old settings
         await prefs.remove('old_settings_key');
       }
     }
   }
   ```

2. **Backwards Compatibility:**
   - Keep reading old settings during transition
   - Gradually write to new format
   - Remove old settings after confirmation

### Settings Screen Migration

#### Before (Individual Implementation)
```dart
class OldSettingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        children: [
          // Custom theme mode selector
          ListTile(
            leading: Icon(Icons.brightness_6),
            title: Text('Theme Mode'),
            trailing: DropdownButton<ThemeMode>(/* ... */),
          ),
          
          // Custom font size slider
          ListTile(
            leading: Icon(Icons.text_fields),
            title: Text('Font Size'),
            subtitle: Slider(/* ... */),
          ),
          
          // Custom about section
          ListTile(
            leading: Icon(Icons.info),
            title: Text('About'),
            onTap: () => showAboutDialog(/* ... */),
          ),
        ],
      ),
    );
  }
}
```

#### After (Unified Components)
```dart
class NewSettingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UnifiedSettingsScreen(
      appInfo: AppInfo(
        appName: 'My App',
        version: '1.0.0',
        description: 'Catholic app description...',
      ),
      appSpecificSettings: Column(
        children: [
          SettingsSectionHeader(title: 'App-Specific'),
          // Only truly app-specific settings here
          AppSpecificSettingTile(),
        ],
      ),
    );
  }
}
```

## Benefits

### For Developers
- **Reduced Code Duplication** - Common settings handled once
- **Consistent APIs** - Same patterns across all apps
- **Easier Maintenance** - Updates in one place benefit all apps
- **Built-in Accessibility** - WCAG compliance out of the box

### For Users
- **Consistent Experience** - Same settings interface across apps
- **Better Accessibility** - Standardized accessibility features
- **Unified Preferences** - Common settings sync across apps
- **Improved UX** - Professional, polished interface

### For the Ecosystem
- **Brand Consistency** - Unified Sancta Via experience
- **Quality Assurance** - Tested components reduce bugs
- **Feature Parity** - All apps benefit from improvements
- **Faster Development** - New apps get full settings for free

## Testing

### Unit Tests
```dart
void main() {
  group('BaseSettingsModel', () {
    test('creates with defaults', () {
      final settings = BaseSettingsModel.defaults();
      expect(settings.fontSize, 18.0);
      expect(settings.defaultLanguage, AppLanguage.english);
    });
    
    test('serializes to/from JSON', () {
      final settings = BaseSettingsModel.defaults();
      final json = settings.toJson();
      final restored = BaseSettingsModel.fromJson(json);
      expect(restored, equals(settings));
    });
  });
}
```

### Integration Tests
```dart
void main() {
  group('Settings Screen Integration', () {
    testWidgets('displays all standard sections', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: UnifiedSettingsScreen(
              appInfo: AppInfo(appName: 'Test', version: '1.0.0'),
            ),
          ),
        ),
      );
      
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Accessibility'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    });
  });
}
```

## Best Practices

1. **Use Base Settings for Common Features**
   - Font size, language, notifications
   - Theme preferences, accessibility
   - Don't duplicate in app-specific models

2. **Extend Thoughtfully**
   - Only add app-specific settings when truly needed
   - Consider if feature could be generalized for other apps
   - Document app-specific decisions

3. **Migration Safety**
   - Always provide default values
   - Handle malformed data gracefully
   - Test migration with real user data

4. **Accessibility First**
   - Use provided text scaling
   - Support reduce motion preference
   - Test with screen readers

5. **Consistent Naming**
   - Use established patterns from shared components
   - Follow Flutter/Material Design conventions
   - Document any deviations

## Future Enhancements

- **Cloud Sync** - Sync common settings across devices
- **Advanced Accessibility** - Voice control, high contrast themes
- **Localization** - Additional language support
- **Analytics** - Settings usage analytics (privacy-respecting)
- **Backup/Restore** - Settings export/import functionality

## Support

For questions or issues with the unified settings system:
1. Check this documentation
2. Review example implementations
3. Check shared_ui package tests
4. Consult with the Sancta Via development team

---

*This unified settings system is part of the Sancta Via ecosystem of Catholic applications. It reflects our commitment to providing consistent, high-quality tools for the faithful.*
