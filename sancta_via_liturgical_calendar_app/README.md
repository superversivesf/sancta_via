# Sancta Via Liturgical Calendar App

A focused Catholic liturgical calendar application with beautiful interface and detailed feast information. This is a standalone Flutter app that utilizes the Sancta Via ecosystem packages hosted on GitHub.

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

This app is built using the Sancta Via ecosystem packages hosted on GitHub:

- [`sancta_via_liturgical_calendar`](https://github.com/superversivesf/sancta_via_liturgical_calendar) - Core liturgical calendar engine
- [`sancta_via_liturgical_calendar_riverpod`](https://github.com/superversivesf/sancta_via_liturgical_calendar_riverpod) - Reactive state management
- [`sancta_via_shared_ui`](https://github.com/superversivesf/sancta_via_shared_ui) - Shared UI components
- Flutter with Material 3 design

## 🚀 Building and Running

### Prerequisites
- Flutter SDK 3.7.2+
- Dart SDK 3.7.2+

### Setup
```bash
# Clone the repository
git clone https://github.com/superversivesf/sancta_via_liturgical_calendar_app.git
cd sancta_via_liturgical_calendar_app

# Get dependencies (this will fetch packages from GitHub)
flutter pub get

# Run the app
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
# Sancta Via packages (from GitHub)
liturgical_calendar:
  git:
    url: https://github.com/superversivesf/sancta_via_liturgical_calendar.git
liturgical_calendar_riverpod:
  git:
    url: https://github.com/superversivesf/sancta_via_liturgical_calendar_riverpod.git
shared_ui:
  git:
    url: https://github.com/superversivesf/sancta_via_shared_ui.git

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

## 🏗️ Building from Source

This app was extracted from the [Sancta Via monorepo](https://github.com/superversive-ca/sancta-via) and configured to use the individual packages as Git dependencies. The packages are maintained separately to allow for modular development and reuse across different applications.

## 📄 License

This app is part of the Sancta Via ecosystem and is licensed under the MIT License.

---

**Building the future of Catholic apps, one focused application at a time.** 🙏✨