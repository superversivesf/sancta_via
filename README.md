# Sancta Via Shared UI

Shared UI components for the **Sancta Via Catholic Apps Ecosystem** with liturgical theming and responsive design.

## 🎨 **Liturgical Theming**

This package provides **automatic liturgical theming** that adapts your app's appearance to the current liturgical season:

- 🟢 **Green** - Ordinary Time (peaceful growth)
- 🟣 **Purple** - Advent & Lent (preparation & penance)  
- 🌸 **Rose** - Gaudete & Laetare Sundays (joyful anticipation)
- ⚪ **White** - Christmas & Easter (celebration & joy)
- 🔴 **Red** - Pentecost & Martyrs (fire of the Spirit)
- 🟡 **Gold** - High Feasts (divine glory)

## 🚀 **Quick Start**

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  sancta_via_shared_ui:
    git:
      url: https://github.com/superversivesf/sancta_via_shared_ui.git
      ref: v1.0.0
```

### Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Theme automatically matches liturgical season!
    final theme = ref.watch(liturgicalThemeProvider);
    
    return MaterialApp(
      theme: theme,  // Purple in Advent, Green in Ordinary Time, etc.
      home: HomePage(),
    );
  }
}

class HomePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liturgicalColor = ref.watch(liturgicalColorProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Catholic App'),
        backgroundColor: liturgicalColor,  // Auto-updates daily!
      ),
      body: Column(
        children: [
          // Preview all liturgical colors
          LiturgicalColorPreview(),
          
          // Let users choose light/dark mode
          ThemeModeSelector(),
          
          // Adjust color intensity
          ColorIntensitySelector(),
        ],
      ),
    );
  }
}
```

## 🎨 **Theme Providers**

### **Automatic Liturgical Theming**
```dart
// Main theme that adapts to liturgical season
final theme = ref.watch(liturgicalThemeProvider);

// Current liturgical color as Flutter Color
final color = ref.watch(liturgicalColorProvider);

// Works with any date
final christmasColor = ref.watch(liturgicalColorByDateProvider(
  DateTime(2025, 12, 25)  // Returns white/gold
));
```

### **User Preferences**
```dart
// Light/dark mode preference
final themeMode = ref.watch(themeModeProvider);
ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);

// Color intensity (vibrant vs muted)
final intensity = ref.watch(colorIntensityProvider);
ref.read(colorIntensityProvider.notifier).setIntensity(ColorIntensity.muted);
```

### **Combined Usage**
```dart
class ThemedWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ref.watch(liturgicalColorProvider);
    final intensity = ref.watch(colorIntensityProvider);
    
    // Get muted or vibrant version
    final adjustedColor = LiturgicalColor.green.toFlutterColor(intensity);
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.3),
            color.withOpacity(0.1),
          ],
        ),
      ),
      child: Text('Liturgical Content'),
    );
  }
}
```

## 🎨 **UI Components**

### **LiturgicalColorPreview**
Interactive widget to preview all liturgical colors:

```dart
LiturgicalColorPreview(
  title: 'Season Colors',
  subtitle: 'See how your app looks in each season',
  onTap: () {
    // Shows beautiful modal with all colors
  },
)
```

### **ThemeModeSelector** 
Elegant light/dark mode toggle:

```dart
ThemeModeSelector(
  title: 'Theme Mode',
  showLabels: true,  // Show "Light"/"Dark" labels
)
```

### **ColorIntensitySelector**
Slider to adjust color vibrancy:

```dart
ColorIntensitySelector(
  title: 'Color Intensity',
  subtitle: 'Choose vibrant or muted colors',
)
```

### **SettingsSectionHeader**
Consistent section headers:

```dart
SettingsSectionHeader('Display Settings')
```

## 🎨 **Color Extensions**

### **LiturgicalColor Extensions**
```dart
// Convert liturgical colors to Flutter colors
final green = LiturgicalColor.green.toFlutterColor();
final mutedPurple = LiturgicalColor.purple.toFlutterColor(ColorIntensity.muted);
final transparentRed = LiturgicalColor.red.toFlutterColorWithOpacity(0.5);

// String-based for backward compatibility
final color = 'GREEN'.toLiturgicalColor();
final mutedColor = 'PURPLE'.toLiturgicalColor(ColorIntensity.muted);
```

### **Intensity Variations**
```dart
enum ColorIntensity { vibrant, muted }

// Vibrant colors for modern UI
final vibrant = LiturgicalColor.red.toFlutterColor(ColorIntensity.vibrant);
// Color(0xFFD32F2F) - Bright red

// Muted colors for subtle themes  
final muted = LiturgicalColor.red.toFlutterColor(ColorIntensity.muted);
// Color(0xFFB85450) - Burgundy red
```

## 🎨 **Theme Configuration**

### **AppTheme Class**
```dart
// Get liturgical-aware themes
final lightTheme = AppTheme.lightTheme(
  LiturgicalColor.purple,  // Liturgical color
  ColorIntensity.vibrant   // Intensity
);

final darkTheme = AppTheme.darkTheme(
  LiturgicalColor.green,
  ColorIntensity.muted
);

// Use in MaterialApp
MaterialApp(
  theme: lightTheme,
  darkTheme: darkTheme,
  home: MyHomePage(),
)
```

### **Typography**
The package includes Catholic-appropriate typography:

```dart
TextTheme(
  headlineLarge: TextStyle(
    fontFamily: 'Crimson',    // Serif for liturgical headings
    fontWeight: FontWeight.bold,
  ),
  titleLarge: TextStyle(
    fontFamily: 'Crimson',    // Serif for important titles
    fontWeight: FontWeight.w600,
  ),
  // Body text uses system default for readability
)
```

## 🎨 **Complete Example**

```dart
import 'package:flutter/material.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

void main() {
  runApp(
    ProviderScope(
      child: CatholicApp(),
    ),
  );
}

class CatholicApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Catholic App',
      theme: ref.watch(liturgicalThemeProvider),
      home: HomePage(),
    );
  }
}

class HomePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liturgicalColor = ref.watch(liturgicalColorProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('My Catholic App'),
        backgroundColor: liturgicalColor,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Current liturgical information
          Card(
            color: liturgicalColor.withOpacity(0.1),
            child: ListTile(
              leading: Icon(Icons.calendar_today, color: liturgicalColor),
              title: Text('Current Liturgical Season'),
              subtitle: Text('Theme adapts automatically'),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Settings section
          SettingsSectionHeader('Display Settings'),
          
          // Theme controls
          ThemeModeSelector(),
          ColorIntensitySelector(),
          LiturgicalColorPreview(),
          
          SizedBox(height: 16),
          
          // Custom themed content
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  liturgicalColor.withOpacity(0.3),
                  liturgicalColor.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Liturgical Content',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: liturgicalColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This content automatically adapts to the liturgical season with appropriate colors and theming.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## 🎨 **Customization**

### **Custom Color Schemes**
```dart
class CustomAppTheme extends AppTheme {
  static ThemeData customLiturgicalTheme(LiturgicalColor liturgicalColor) {
    return lightTheme(liturgicalColor, ColorIntensity.vibrant).copyWith(
      // Add custom overrides
      appBarTheme: AppBarTheme(
        backgroundColor: liturgicalColor.toFlutterColor(),
        foregroundColor: Colors.white,
      ),
    );
  }
}
```

### **Custom Color Intensities**
```dart
extension CustomColorIntensity on LiturgicalColor {
  Color toCustomColor() {
    switch (this) {
      case LiturgicalColor.green:
        return Color(0xFF2E7D32); // Your custom green
      case LiturgicalColor.purple:
        return Color(0xFF512DA8); // Your custom purple
      // ... etc
    }
  }
}
```

## 🔄 **Compatibility**

- **Dart**: 3.0.0+
- **Flutter**: 3.0.0+
- **Dependencies**: 
  - `sancta_via_liturgical_calendar` v2.0.0+
  - `flutter_riverpod` 2.5.1+
  - `shared_preferences` 2.2.2+

## 🏗️ **Part of Sancta Via Ecosystem**

This package is part of the broader Sancta Via Catholic Apps ecosystem:

- **sancta_via_liturgical_calendar** - Core liturgical calendar (this package depends on it)
- **sancta_via_liturgical_calendar_riverpod** - Riverpod providers for reactive data
- **sancta_via_shared_ui** - Shared UI components (this package)
- Various Catholic prayer and devotion apps

## 🤝 **Contributing**

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

## 📄 **License**

MIT License - see [LICENSE](LICENSE) file for details.

---

**Beautiful liturgical theming for Catholic Flutter apps.** 🎨✨
*Part of the Sancta Via Catholic Apps Ecosystem*