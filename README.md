# Sancta Via Calendar App

A focused Catholic liturgical calendar application with beautiful interface and detailed feast information.

## 🎯 Features

- **Beautiful Calendar Interface** - Monthly grid view with liturgical color coding
- **Detailed Day Information** - Complete liturgical data for each day
- **Celebration Search** - Find feasts, saints, and liturgical celebrations
- **Upcoming Feasts** - Scrollable list of upcoming celebrations
- **Liturgical Theming** - App colors adapt to current liturgical season
- **Zero Loading Time** - Data is embedded for instant access

## 📅 Liturgical Data

- **12 years** of data (2024-2035)
- **4,383 liturgical days** with complete information
- **856 prioritized celebrations** 
- **All liturgical seasons** and colors
- **Generated from RomCal** - authoritative Roman Calendar

## 🏗️ Architecture

This app is built using the Sancta Via ecosystem packages:

- `liturgical_calendar` - Core liturgical calendar engine
- `liturgical_calendar_riverpod` - Reactive state management
- Flutter with Material 3 design

## 🚀 Building and Running

### Prerequisites
- Flutter SDK 3.7.2+
- Dart SDK 3.7.2+

### Setup
```bash
# From the monorepo root
melos bootstrap

# Run the app
cd apps/liturgical_calendar_app
flutter run
```

### Platform Support
- ✅ iOS 
- ✅ Android
- ✅ Web
- ✅ macOS
- ✅ Windows
- ✅ Linux

## 📱 App Structure

```
lib/
├── app/                    # Main app configuration
├── config/                 # Theme, routes, constants
├── screens/               
│   ├── home/              # Main navigation
│   ├── calendar/          # Calendar grid and navigation
│   ├── day_detail/        # Detailed day information
│   ├── search/            # Celebration search
│   └── settings/          # App settings and info
├── providers/             # App-specific Riverpod providers
├── widgets/               # Reusable UI components
└── main.dart             # App entry point
```

## 🎨 Features Showcase

### Calendar View
- Monthly grid with liturgical colors
- Visual indicators for significant celebrations
- Today highlighting and date selection
- Month navigation with smooth transitions

### Day Detail
- Complete liturgical information
- Celebration rank and significance
- Liturgical year and psalter week data
- Beautiful color-coded design

### Search
- Fast celebration search across all years
- Filter by name, saint, feast type
- Date-based results with full context
- Suggestion chips for common searches

### Settings
- App and data information
- Liturgical calendar statistics
- Support and feedback options

## 🔧 Development

### Package Dependencies
```yaml
# Local packages
liturgical_calendar: (path)
liturgical_calendar_riverpod: (path)

# External packages  
flutter_riverpod: ^2.6.1
intl: ^0.19.0
flutter_staggered_animations: ^1.1.1
```

### Code Organization
- **Screens** - Feature-based screen organization
- **Providers** - Riverpod state management
- **Widgets** - Reusable UI components
- **Config** - App-wide configuration

## 📄 License

This app is part of the Sancta Via ecosystem and is licensed under the MIT License.

---

**Building the future of Catholic apps, one focused application at a time.** 🙏✨